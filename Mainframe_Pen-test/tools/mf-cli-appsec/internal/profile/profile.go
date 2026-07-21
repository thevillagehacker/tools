package profile

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// LoginProfile is a reusable logon keystroke sequence for any TN3270 estate.
// Different sites use different panels; swap profiles without rewriting every scenario.
type LoginProfile struct {
	ID          string      `yaml:"id"`
	Name        string      `yaml:"name"`
	Description string      `yaml:"description"`
	// Platforms this profile is known to fit (documentation / filtering).
	Platforms []string `yaml:"platforms"`
	Steps     []Step   `yaml:"steps"`
}

// DenyProfile is a list of screen substrings that mean "access blocked".
// Covers RACF / ACF2 / Top Secret / generic English / common vendor messages.
type DenyProfile struct {
	ID          string   `yaml:"id"`
	Name        string   `yaml:"name"`
	Description string   `yaml:"description"`
	Platforms   []string `yaml:"platforms"`
	Markers     []string `yaml:"markers"`
}

// Step mirrors scenario steps (subset) so login profiles stay pure YAML.
type Step struct {
	Action  string `yaml:"action"`
	Text    string `yaml:"text,omitempty"`
	Name    string `yaml:"name,omitempty"`
	Label   string `yaml:"label,omitempty"`
	Key     string `yaml:"key,omitempty"`
	Seconds int    `yaml:"seconds,omitempty"`
	MS      int    `yaml:"ms,omitempty"`
}

func LoadLogin(dir, id string) (LoginProfile, error) {
	if id == "" {
		return LoginProfile{}, fmt.Errorf("empty login profile id")
	}
	path, err := resolve(dir, id, []string{"login", "logins", ""})
	if err != nil {
		return LoginProfile{}, err
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return LoginProfile{}, err
	}
	var p LoginProfile
	if err := yaml.Unmarshal(raw, &p); err != nil {
		return LoginProfile{}, err
	}
	if p.ID == "" {
		p.ID = id
	}
	if len(p.Steps) == 0 {
		return LoginProfile{}, fmt.Errorf("login profile %s has no steps", id)
	}
	return p, nil
}

func LoadDeny(dir, id string) (DenyProfile, error) {
	if id == "" {
		id = "global-deny"
	}
	path, err := resolve(dir, id, []string{"deny", "denies", ""})
	if err != nil {
		// Fall back to built-in global markers so tool always works offline.
		return BuiltinDeny(), nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return BuiltinDeny(), nil
	}
	var p DenyProfile
	if err := yaml.Unmarshal(raw, &p); err != nil {
		return BuiltinDeny(), nil
	}
	if len(p.Markers) == 0 {
		return BuiltinDeny(), nil
	}
	if p.ID == "" {
		p.ID = id
	}
	return p, nil
}

func resolve(dir, id string, subdirs []string) (string, error) {
	candidates := []string{}
	for _, sub := range subdirs {
		base := dir
		if sub != "" {
			base = filepath.Join(dir, sub)
		}
		for _, ext := range []string{".yaml", ".yml"} {
			candidates = append(candidates, filepath.Join(base, id+ext))
		}
	}
	// Also allow id already containing path.
	candidates = append(candidates, id)
	for _, c := range candidates {
		if st, err := os.Stat(c); err == nil && !st.IsDir() {
			return c, nil
		}
	}
	return "", fmt.Errorf("profile %q not found under %s", id, dir)
}

// BuiltinDeny is used when no file exists — global, multi-ESM, multi-language-ish English markers.
func BuiltinDeny() DenyProfile {
	return DenyProfile{
		ID:   "builtin-global-deny",
		Name: "Built-in global access-denied markers",
		Markers: []string{
			// Generic English
			"NOT AUTHORIZED",
			"NOT AUTHORISED",
			"ACCESS DENIED",
			"UNAUTHORIZED",
			"UNAUTHORISED",
			"NOT ALLOWED",
			"NOT PERMITTED",
			"PERMISSION DENIED",
			"INVALID REQUEST",
			"SECURITY VIOLATION",
			"SECURITY ERROR",
			"INSUFFICIENT AUTHORITY",
			"INSUFFICIENT ACCESS",
			"ACCESS IS DENIED",
			"YOU ARE NOT AUTHORIZED",
			"NOT AUTHORISED TO",
			"NOT AUTHORIZED TO",
			"LOGON FAILED",
			"LOGON REJECTED",
			"SIGNON FAILED",
			"SIGN-ON FAILED",
			"INVALID USER",
			"INVALID USERID",
			"INVALID PASSWORD",
			"PASSWORD NOT AUTHORIZED",
			// IBM RACF-ish
			"ICH408I",
			"ICH408",
			"IRR012I",
			"RACF",
			// Broadcom ACF2 / Top Secret
			"ACF0",
			"ACF00",
			"TSS",
			"TSS7251",
			"TSS7100",
			// CICS / common middleware
			"DFHAC",
			"NOT AUTH",
			"ABEND AEY7",
			// Session managers / generic menus
			"APPLICATION NOT AVAILABLE",
			"UNABLE TO LOGON",
			"SELECTION INVALID",
			"INVALID SELECTION",
			"UNKNOWN APPLICATION",
		},
	}
}

// MergeMarkers returns unique markers (profile + extras), uppercased for compare helpers.
func MergeMarkers(base []string, extra ...string) []string {
	seen := map[string]struct{}{}
	var out []string
	add := func(s string) {
		s = strings.TrimSpace(s)
		if s == "" {
			return
		}
		u := strings.ToUpper(s)
		if _, ok := seen[u]; ok {
			return
		}
		seen[u] = struct{}{}
		out = append(out, s)
	}
	for _, m := range base {
		add(m)
	}
	for _, m := range extra {
		add(m)
	}
	return out
}

// MatchDenied returns true if screen contains any marker (case-insensitive).
func MatchDenied(screen string, markers []string) (bool, string) {
	up := strings.ToUpper(screen)
	for _, m := range markers {
		if m == "" {
			continue
		}
		if strings.Contains(up, strings.ToUpper(m)) {
			return true, m
		}
	}
	return false, ""
}
