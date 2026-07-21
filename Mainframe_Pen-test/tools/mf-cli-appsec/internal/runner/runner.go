package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/notestream/mf-cli-appsec/internal/config"
	"github.com/notestream/mf-cli-appsec/internal/profile"
	"github.com/notestream/mf-cli-appsec/internal/report"
	"github.com/notestream/mf-cli-appsec/internal/s3270"
	"github.com/notestream/mf-cli-appsec/internal/scenario"
)

// Config is runtime wiring for one scenario execution.
type Config struct {
	Host        string
	Port        int
	OutDir      string
	S3270Path   string
	UseSSL      bool
	ProfilesDir string
	// Site carries defaults (login/deny profiles, extra markers, platform).
	Site config.Site
}

func Run(cfg Config, sc scenario.Scenario) (report.Result, error) {
	start := time.Now().UTC()
	evDir := filepath.Join(cfg.OutDir, "evidence")
	if err := os.MkdirAll(evDir, 0o755); err != nil {
		return report.Result{}, err
	}

	if err := config.ValidateProtocol(sc.Protocol); err != nil {
		res := report.Result{
			ScenarioID: sc.ID, App: sc.App, Name: sc.Name,
			Status: "ERROR", Error: err.Error(),
			Started: start, Finished: time.Now().UTC(),
		}
		return res, err
	}

	// Resolve profiles (scenario overrides site).
	profilesDir := cfg.ProfilesDir
	if profilesDir == "" {
		profilesDir = cfg.Site.ProfilesDir
	}
	if profilesDir == "" {
		profilesDir = "profiles"
	}

	loginID := sc.LoginProfile
	if loginID == "" {
		loginID = cfg.Site.LoginProfile
	}
	if loginID == "" {
		loginID = "generic-userid-password-tab"
	}

	denyID := sc.DenyProfile
	if denyID == "" {
		denyID = cfg.Site.DenyProfile
	}
	if denyID == "" {
		denyID = "global-deny"
	}

	loginProf, loginErr := profile.LoadLogin(profilesDir, loginID)
	// loginErr deferred until a login step actually runs (dry connect-only scenarios).

	denyProf, _ := profile.LoadDeny(profilesDir, denyID)
	markers := profile.MergeMarkers(denyProf.Markers, append(cfg.Site.ExtraDenyMarkers, sc.DenyMarkers...)...)

	platform := sc.Platform
	if platform == "" {
		platform = cfg.Site.Platform
	}

	res := report.Result{
		ScenarioID:   sc.ID,
		App:          sc.App,
		Name:         sc.Name,
		SeverityHint: sc.SeverityHint,
		Platform:     platform,
		Protocol:     sc.Protocol,
		Tags:         sc.Tags,
		EvidenceDir:  evDir,
		Started:      start,
	}

	client, err := s3270.Start(cfg.S3270Path)
	if err != nil {
		res.Status = "ERROR"
		res.Error = err.Error()
		res.Finished = time.Now().UTC()
		return res, err
	}
	defer func() { _ = client.Close() }()

	ctx := &execContext{
		client:     client,
		cfg:        cfg,
		sc:         sc,
		evDir:      evDir,
		loginProf:  loginProf,
		loginErr:   loginErr,
		denyMarkers: markers,
	}

	failed := false
	for i, step := range sc.Steps {
		stepRes := report.StepResult{Index: i, Action: step.Action, OK: true}
		err := ctx.execute(step)
		if err != nil {
			stepRes.OK = false
			stepRes.Error = err.Error()
			if isAssert(step.Action) {
				failed = true
				res.Findings = append(res.Findings, report.Finding{
					Title:    fmt.Sprintf("Assertion failed: %s", step.Action),
					Detail:   err.Error(),
					Severity: defaultSeverity(sc.SeverityHint),
					Evidence: snippet(ctx.lastScreen),
				})
			} else {
				if scr, e2 := client.Ascii(); e2 == nil {
					ctx.lastScreen = scr
					_ = os.WriteFile(filepath.Join(evDir, "error_screen.txt"), []byte(scr), 0o644)
				}
				res.Status = "ERROR"
				res.Error = fmt.Sprintf("step %d (%s): %v", i, step.Action, err)
				res.Steps = append(res.Steps, stepRes)
				res.Finished = time.Now().UTC()
				return res, err
			}
		}
		res.Steps = append(res.Steps, stepRes)
	}

	if failed {
		res.Status = "FAIL"
	} else {
		res.Status = "PASS"
	}
	res.Finished = time.Now().UTC()
	return res, nil
}

type execContext struct {
	client      *s3270.Client
	cfg         Config
	sc          scenario.Scenario
	evDir       string
	lastScreen  string
	loginProf   profile.LoginProfile
	loginErr    error
	denyMarkers []string
}

func isAssert(action string) bool {
	switch strings.ToLower(action) {
	case "assert_contains", "assert_not_contains", "assert_denied", "assert_any_contains":
		return true
	default:
		return false
	}
}

func defaultSeverity(hint string) string {
	if hint == "" {
		return "medium"
	}
	return hint
}

func snippet(s string) string {
	if len(s) > 2500 {
		return s[:2500] + "\n...[truncated]..."
	}
	return s
}

func (x *execContext) execute(step scenario.Step) error {
	switch strings.ToLower(strings.TrimSpace(step.Action)) {
	case "comment":
		return nil

	case "pause":
		d := time.Duration(step.MS) * time.Millisecond
		if step.Seconds > 0 {
			d = time.Duration(step.Seconds) * time.Second
		}
		if d == 0 {
			d = time.Second
		}
		time.Sleep(d)
		return nil

	case "connect":
		var err error
		if x.cfg.UseSSL || step.Text == "ssl" || step.Text == "tls" {
			err = x.client.ConnectSSL(x.cfg.Host, x.cfg.Port)
		} else {
			err = x.client.Connect(x.cfg.Host, x.cfg.Port)
		}
		if err != nil {
			return err
		}
		_ = x.client.WaitTimeout(30, "InputField")
		return nil

	case "disconnect":
		return x.client.Disconnect()

	case "wait":
		mode := step.Text
		if mode == "" {
			mode = "InputField"
		}
		if step.Seconds > 0 {
			return x.client.WaitTimeout(step.Seconds, mode)
		}
		return x.client.Wait(mode)

	case "string":
		return x.client.String(x.expand(step.Text))

	case "type_field":
		// erase_eof + string — portable way to overwrite a 3270 field
		if err := x.client.EraseEOF(); err != nil {
			return err
		}
		return x.client.String(x.expand(step.Text))

	case "enter":
		return x.client.Enter()

	case "clear":
		return x.client.Clear()

	case "tab":
		n := 1
		if step.Text != "" {
			if v, err := strconv.Atoi(step.Text); err == nil && v > 0 {
				n = v
			}
		}
		for i := 0; i < n; i++ {
			if err := x.client.Tab(); err != nil {
				return err
			}
		}
		return nil

	case "backtab":
		return x.client.BackTab()

	case "erase_eof":
		return x.client.EraseEOF()

	case "home":
		return x.client.Home()

	case "move_cursor":
		parts := strings.Split(step.Text, ",")
		if len(parts) != 2 {
			return fmt.Errorf("move_cursor requires text: \"row,col\" (zero-origin)")
		}
		row, err1 := strconv.Atoi(strings.TrimSpace(parts[0]))
		col, err2 := strconv.Atoi(strings.TrimSpace(parts[1]))
		if err1 != nil || err2 != nil {
			return fmt.Errorf("move_cursor: invalid row/col")
		}
		return x.client.MoveCursor(row, col)

	case "pf":
		n, err := parsePF(step)
		if err != nil {
			return err
		}
		return x.client.PF(n)

	case "pa":
		n, err := strconv.Atoi(strings.TrimSpace(step.Text))
		if err != nil {
			return fmt.Errorf("pa requires text: 1|2|3")
		}
		return x.client.PA(n)

	case "login":
		// Prefer profile-driven login (global); fall back to classic tab login.
		profID := step.Profile
		if profID != "" {
			p, err := profile.LoadLogin(x.profilesDir(), profID)
			if err != nil {
				return err
			}
			return x.runLoginSteps(p.Steps)
		}
		if x.loginErr != nil {
			// Built-in generic fallback so tool works without profiles tree.
			return x.builtinLogin()
		}
		return x.runLoginSteps(x.loginProf.Steps)

	case "select_app":
		name := x.expand(step.Text)
		if name == "" {
			return fmt.Errorf("select_app requires text: application name, APPLID, or menu number")
		}
		if err := x.client.String(name); err != nil {
			return err
		}
		if err := x.client.Enter(); err != nil {
			return err
		}
		_ = x.client.WaitTimeout(30, "InputField")
		return nil

	case "tab_to":
		label := strings.ToUpper(step.Label)
		if label == "" {
			label = strings.ToUpper(step.Text)
		}
		if label == "" {
			return fmt.Errorf("tab_to requires label or text")
		}
		for i := 0; i < 48; i++ {
			scr, err := x.client.Ascii()
			if err != nil {
				return err
			}
			x.lastScreen = scr
			if strings.Contains(strings.ToUpper(scr), label) {
				return nil
			}
			if err := x.client.Tab(); err != nil {
				return err
			}
		}
		return fmt.Errorf("tab_to: label %q not found after 48 tabs", label)

	case "snapshot":
		scr, err := x.client.Ascii()
		if err != nil {
			return err
		}
		x.lastScreen = scr
		name := step.Name
		if name == "" {
			name = fmt.Sprintf("snap_%d", time.Now().UnixNano())
		}
		path := filepath.Join(x.evDir, sanitizeFile(name)+".txt")
		return os.WriteFile(path, []byte(scr), 0o644)

	case "snap_save":
		return x.client.SnapSave()

	case "assert_contains":
		scr, err := x.refreshScreen()
		if err != nil {
			return err
		}
		want := x.expand(step.Text)
		if !strings.Contains(scr, want) {
			return fmt.Errorf("screen does not contain %q", want)
		}
		return nil

	case "assert_any_contains":
		// text: "FOO|BAR|BAZ" — PASS if any alternative present
		scr, err := x.refreshScreen()
		if err != nil {
			return err
		}
		parts := strings.Split(x.expand(step.Text), "|")
		for _, p := range parts {
			p = strings.TrimSpace(p)
			if p != "" && strings.Contains(scr, p) {
				return nil
			}
		}
		return fmt.Errorf("screen contains none of: %s", step.Text)

	case "assert_not_contains":
		scr, err := x.refreshScreen()
		if err != nil {
			return err
		}
		forbid := x.expand(step.Text)
		if strings.Contains(scr, forbid) {
			return fmt.Errorf("screen unexpectedly contains %q (possible authZ/IDOR/data-exposure issue)", forbid)
		}
		return nil

	case "assert_denied":
		scr, err := x.refreshScreen()
		if err != nil {
			return err
		}
		ok, hit := profile.MatchDenied(scr, x.denyMarkers)
		if ok {
			_ = hit
			return nil
		}
		return fmt.Errorf("expected access-denial markers not found (profile markers checked: %d)", len(x.denyMarkers))

	default:
		return fmt.Errorf("unknown action %q", step.Action)
	}
}

func (x *execContext) profilesDir() string {
	if x.cfg.ProfilesDir != "" {
		return x.cfg.ProfilesDir
	}
	if x.cfg.Site.ProfilesDir != "" {
		return x.cfg.Site.ProfilesDir
	}
	return "profiles"
}

func (x *execContext) builtinLogin() error {
	user := x.sc.Defaults.User
	pass := x.sc.Defaults.Password
	if user == "" || pass == "" {
		return fmt.Errorf("login requires user/password (--user/--pass or MF_USER/MF_PASS); also missing login profile: %v", x.loginErr)
	}
	if err := x.client.String(user); err != nil {
		return err
	}
	if err := x.client.Tab(); err != nil {
		return err
	}
	if err := x.client.String(pass); err != nil {
		return err
	}
	if err := x.client.Enter(); err != nil {
		return err
	}
	_ = x.client.WaitTimeout(30, "InputField")
	return nil
}

func (x *execContext) runLoginSteps(steps []profile.Step) error {
	user := x.sc.Defaults.User
	pass := x.sc.Defaults.Password
	if user == "" || pass == "" {
		return fmt.Errorf("login requires defaults.user/password or --user/--pass / MF_USER/MF_PASS")
	}
	for _, ps := range steps {
		// Map profile step → scenario step and expand {{user}}/{{password}}
		st := scenario.Step{
			Action:  ps.Action,
			Text:    ps.Text,
			Name:    ps.Name,
			Label:   ps.Label,
			Key:     ps.Key,
			Seconds: ps.Seconds,
			MS:      ps.MS,
		}
		// Expand credentials in text before generic expand
		st.Text = strings.ReplaceAll(st.Text, "{{password}}", pass)
		st.Text = strings.ReplaceAll(st.Text, "{{pass}}", pass)
		st.Text = strings.ReplaceAll(st.Text, "{{user}}", user)
		st.Text = strings.ReplaceAll(st.Text, "{{userid}}", user)
		if err := x.execute(st); err != nil {
			return fmt.Errorf("login profile step %s: %w", ps.Action, err)
		}
	}
	_ = x.client.WaitTimeout(30, "InputField")
	return nil
}

func (x *execContext) refreshScreen() (string, error) {
	scr, err := x.client.Ascii()
	if err != nil {
		return "", err
	}
	x.lastScreen = scr
	return scr, nil
}

func (x *execContext) expand(text string) string {
	out := text
	for k, v := range x.sc.Roles {
		out = strings.ReplaceAll(out, "{{roles."+k+"}}", v)
		out = strings.ReplaceAll(out, "{{"+k+"}}", v)
	}
	out = strings.ReplaceAll(out, "{{user}}", x.sc.Defaults.User)
	out = strings.ReplaceAll(out, "{{userid}}", x.sc.Defaults.User)
	out = strings.ReplaceAll(out, "{{password}}", x.sc.Defaults.Password)
	return out
}

func parsePF(step scenario.Step) (int, error) {
	raw := step.Key
	if raw == "" {
		raw = step.Text
	}
	if raw == "" {
		return 0, fmt.Errorf("pf requires key: PF3 or text: 3")
	}
	re := regexp.MustCompile(`(?i)PF\s*(\d{1,2})`)
	if m := re.FindStringSubmatch(raw); len(m) == 2 {
		return strconv.Atoi(m[1])
	}
	return strconv.Atoi(strings.TrimSpace(raw))
}

func sanitizeFile(s string) string {
	s = strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-', r == '_':
			return r
		default:
			return '_'
		}
	}, s)
	if s == "" {
		return "snap"
	}
	return s
}
