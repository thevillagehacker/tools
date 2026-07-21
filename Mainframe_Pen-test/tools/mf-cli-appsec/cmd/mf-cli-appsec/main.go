// mf-cli-appsec — authorized global TN3270 console/CLI mainframe app security harness.
//
// Same binary works against any authorized estate that speaks TN3270 (IBM z/OS, z/VM,
// z/VSE, CICS/IMS/TSO menus, session managers, and other 3270-compatible systems).
// Site-specific behaviour is data (YAML site config, login/deny profiles, scenarios),
// not hard-coded app logic.
//
// Not in scope of this binary: IBM i 5250, raw SSH/USS (use native clients).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/notestream/mf-cli-appsec/internal/config"
	"github.com/notestream/mf-cli-appsec/internal/probe"
	"github.com/notestream/mf-cli-appsec/internal/report"
	"github.com/notestream/mf-cli-appsec/internal/runner"
	"github.com/notestream/mf-cli-appsec/internal/s3270"
	"github.com/notestream/mf-cli-appsec/internal/scenario"
	"github.com/notestream/mf-cli-appsec/internal/util"
)

const version = "mf-cli-appsec v0.3.0 windows (global-tn3270)"

const banner = `mf-cli-appsec — Global TN3270 mainframe console/CLI app security harness
Authorized testing only. Prefer TEST/QA. Site-specific data lives in YAML, not code.
`

func main() {
	if len(os.Args) < 2 {
		printHelp()
		os.Exit(2)
	}

	cmd := os.Args[1]
	args := os.Args[2:]

	switch cmd {
	case "help", "-h", "--help":
		printHelp()
	case "version":
		fmt.Println(version)
	case "platforms":
		printPlatforms()
	case "probe":
		runProbe(args)
	case "which-s3270":
		runWhichS3270(args)
	case "run":
		runScenario(args)
	case "run-pack":
		runPack(args)
	case "report":
		runReport(args)
	case "wordlist":
		runWordlist(args)
	case "ebcdic":
		runEbcdic(args)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", cmd)
		printHelp()
		os.Exit(2)
	}
}

func printHelp() {
	fmt.Print(banner)
	fmt.Print(`
Usage:
  mf-cli-appsec <command> [options]

Commands:
  platforms    List protocol/platform coverage (what this binary supports)
  probe        TCP reachability check
  which-s3270  Show resolved s3270.exe path (wc3270 install)
  run          Execute a single YAML scenario (any TN3270 estate)
  run-pack     Execute scenarios in a directory (optional recursive + tags)
  report       Convert results JSON to Markdown
  wordlist     Generate ID / field fuzz lists
  ebcdic       ASCII ↔ EBCDIC-US helper
  version      Print version
  help         This help

Global options (run / run-pack):
  --config path.yaml   Site config (host, port, ssl, login/deny profiles)
  --profiles-dir dir   Login/deny profile directory (default: profiles)

Examples:
  mf-cli-appsec.exe platforms
  mf-cli-appsec.exe run --config configs\site.example.yaml --scenario scenarios\global\01_smoke_connect_login.yaml --dry-run
  mf-cli-appsec.exe run --config configs\mysite.yaml --scenario scenarios\global\02_session_menu_select.yaml --out out\menu
  mf-cli-appsec.exe run-pack --config configs\mysite.yaml --dir scenarios\global --recursive --tags smoke,menu --out out\pack

Requires live TN3270: s3270.exe from wc3270. Interactive exploration: wc3270.
`)
}

func printPlatforms() {
	fmt.Println("Supported protocols:", strings.Join(config.SupportedProtocols(), ", "))
	fmt.Println()
	fmt.Println("Platform labels (use in site.yaml / scenario platform: field):")
	for k, v := range config.PlatformCatalog() {
		fmt.Printf("  %-18s %s\n", k, v)
	}
	fmt.Println()
	fmt.Println("Technique coverage is protocol-level (TN3270 keystrokes + assertions),")
	fmt.Println("so the same scenarios apply to any mainframe that presents a 3270 app list/logon.")
	fmt.Println("IBM i (5250) and pure SSH/USS are intentionally out of band for this binary.")
}

func loadSite(path string) config.Site {
	s, err := config.LoadSite(path)
	if err != nil {
		fail("%v", err)
	}
	return s
}

func runWhichS3270(args []string) {
	fs := flag.NewFlagSet("which-s3270", flag.ExitOnError)
	explicit := fs.String("s3270", "", "Optional explicit path")
	_ = fs.Parse(args)
	p := s3270.ResolvePath(*explicit)
	fmt.Println(p)
	if st, err := os.Stat(p); err != nil {
		fmt.Fprintf(os.Stderr, "warning: not found yet — install wc3270 and re-run\n")
	} else {
		fmt.Fprintf(os.Stderr, "ok (%d bytes)\n", st.Size())
	}
}

func runProbe(args []string) {
	fs := flag.NewFlagSet("probe", flag.ExitOnError)
	cfgPath := fs.String("config", "", "Optional site.yaml")
	host := fs.String("host", "", "Target host/IP")
	port := fs.Int("port", 0, "TCP port (0 = site default or 23)")
	timeout := fs.Duration("timeout", 5*time.Second, "Dial timeout")
	tryS3270 := fs.Bool("s3270", false, "Also check s3270 binary presence")
	_ = fs.Parse(args)

	site := loadSite(*cfgPath)
	h, p, _ := site.MergeHostPort(*host, *port, nil)
	if h == "" {
		fail("--host is required (or set host in --config)")
	}
	if p == 0 {
		p = 23
	}

	res := probe.TCP(h, p, *timeout)
	fmt.Printf("tcp %s:%d -> %s (%s)\n", h, p, res.Status, res.Detail)

	if *tryS3270 {
		sres := probe.S3270(h, p, *timeout)
		fmt.Printf("s3270 -> %s (%s)\n", sres.Status, sres.Detail)
	}
}

func runScenario(args []string) {
	fs := flag.NewFlagSet("run", flag.ExitOnError)
	cfgPath := fs.String("config", "", "Site config YAML (host/profiles)")
	host := fs.String("host", "", "Target host/IP (overrides config)")
	port := fs.Int("port", 0, "TN3270 port (0 = config/default 23)")
	scenarioPath := fs.String("scenario", "", "Path to YAML scenario")
	user := fs.String("user", "", "Login userid")
	pass := fs.String("pass", "", "Login password (prefer MF_PASS)")
	outDir := fs.String("out", "out/run", "Output directory")
	s3270Path := fs.String("s3270", "", "s3270 binary")
	profilesDir := fs.String("profiles-dir", "", "Profiles directory")
	sslFlag := fs.Bool("ssl", false, "Force TLS L: tunnel")
	sslSet := false
	dryRun := fs.Bool("dry-run", false, "Parse only")
	_ = fs.Parse(args)
	// Detect if user passed --ssl (flag package always sets bool; we treat presence of ssl from site OR flag).
	// If site has ssl:true and user did not want it, they can use port without --ssl only when site.ssl false.
	// For simplicity: --ssl ORs with site.SSL
	for _, a := range args {
		if a == "--ssl" {
			sslSet = true
		}
	}
	_ = sslSet

	if *scenarioPath == "" {
		fail("--scenario is required")
	}
	if *pass == "" {
		*pass = os.Getenv("MF_PASS")
	}
	if *user == "" {
		*user = os.Getenv("MF_USER")
	}

	site := loadSite(*cfgPath)
	sc, err := scenario.Load(*scenarioPath)
	if err != nil {
		fail("load scenario: %v", err)
	}
	if *user != "" {
		sc.Defaults.User = *user
	}
	if *pass != "" {
		sc.Defaults.Password = *pass
	}
	// Inherit profiles from site when scenario omits them.
	if sc.LoginProfile == "" {
		sc.LoginProfile = site.LoginProfile
	}
	if sc.DenyProfile == "" {
		sc.DenyProfile = site.DenyProfile
	}
	if sc.Platform == "" || sc.Platform == "generic-tn3270" {
		if site.Platform != "" {
			sc.Platform = site.Platform
		}
	}

	if *dryRun {
		fmt.Printf("OK dry-run: %s steps=%d app=%s id=%s platform=%s protocol=%s login_profile=%s\n",
			*scenarioPath, len(sc.Steps), sc.App, sc.ID, sc.Platform, sc.Protocol, sc.LoginProfile)
		return
	}

	h, p, useSSL := site.MergeHostPort(*host, *port, nil)
	if *sslFlag {
		useSSL = true
	}
	if h == "" {
		fail("--host is required unless set in --config (or use --dry-run)")
	}
	if p == 0 {
		p = 23
	}
	if *s3270Path == "" {
		*s3270Path = site.S3270Path
	}
	pdir := *profilesDir
	if pdir == "" {
		pdir = site.ProfilesDir
	}
	if pdir == "" {
		pdir = "profiles"
	}

	if err := os.MkdirAll(*outDir, 0o755); err != nil {
		fail("mkdir out: %v", err)
	}

	rcfg := runner.Config{
		Host:        h,
		Port:        p,
		OutDir:      *outDir,
		S3270Path:   *s3270Path,
		UseSSL:      useSSL,
		ProfilesDir: pdir,
		Site:        site,
	}

	result, err := runner.Run(rcfg, sc)
	outJSON := filepath.Join(*outDir, sanitize(sc.ID)+".json")
	_ = report.WriteJSON(outJSON, result)
	if err != nil {
		fail("run: %v", err)
	}
	fmt.Printf("status=%s findings=%d platform=%s evidence=%s json=%s\n",
		result.Status, len(result.Findings), result.Platform, result.EvidenceDir, outJSON)
	if result.Status == "FAIL" {
		os.Exit(1)
	}
}

func runPack(args []string) {
	fs := flag.NewFlagSet("run-pack", flag.ExitOnError)
	cfgPath := fs.String("config", "", "Site config YAML")
	host := fs.String("host", "", "Target host")
	port := fs.Int("port", 0, "TN3270 port")
	dir := fs.String("dir", "", "Directory of YAML scenarios")
	user := fs.String("user", "", "Login userid")
	pass := fs.String("pass", "", "Login password")
	outDir := fs.String("out", "out/pack", "Output directory")
	delay := fs.Duration("delay", 0, "Delay between scenarios (0 = 500ms or site)")
	s3270Path := fs.String("s3270", "", "s3270 binary")
	profilesDir := fs.String("profiles-dir", "", "Profiles directory")
	sslFlag := fs.Bool("ssl", false, "TLS tunnel")
	recursive := fs.Bool("recursive", false, "Walk subdirectories for YAML")
	tags := fs.String("tags", "", "Comma-separated tags filter (any match)")
	_ = fs.Parse(args)

	if *dir == "" {
		fail("--dir is required")
	}
	if *pass == "" {
		*pass = os.Getenv("MF_PASS")
	}
	if *user == "" {
		*user = os.Getenv("MF_USER")
	}

	site := loadSite(*cfgPath)
	h, p, useSSL := site.MergeHostPort(*host, *port, nil)
	if *sslFlag {
		useSSL = true
	}
	if h == "" {
		fail("--host is required (or set in --config)")
	}
	if p == 0 {
		p = 23
	}
	if *s3270Path == "" {
		*s3270Path = site.S3270Path
	}
	pdir := *profilesDir
	if pdir == "" {
		pdir = site.ProfilesDir
	}
	if pdir == "" {
		pdir = "profiles"
	}

	d := *delay
	if d == 0 {
		d = 500 * time.Millisecond
	}

	files, err := scenario.ListYAML(*dir, *recursive)
	if err != nil {
		fail("list scenarios: %v", err)
	}
	if *tags != "" {
		var tagList []string
		for _, t := range strings.Split(*tags, ",") {
			t = strings.TrimSpace(t)
			if t != "" {
				tagList = append(tagList, t)
			}
		}
		files, err = scenario.FilterByTags(files, tagList)
		if err != nil {
			fail("filter tags: %v", err)
		}
	}
	if len(files) == 0 {
		fail("no matching YAML scenarios in %s", *dir)
	}

	if err := os.MkdirAll(*outDir, 0o755); err != nil {
		fail("mkdir: %v", err)
	}

	var all []report.Result
	failCount := 0
	for i, f := range files {
		sc, err := scenario.Load(f)
		if err != nil {
			fmt.Fprintf(os.Stderr, "skip %s: %v\n", f, err)
			continue
		}
		if *user != "" {
			sc.Defaults.User = *user
		}
		if *pass != "" {
			sc.Defaults.Password = *pass
		}
		if sc.LoginProfile == "" {
			sc.LoginProfile = site.LoginProfile
		}
		if sc.DenyProfile == "" {
			sc.DenyProfile = site.DenyProfile
		}

		sub := filepath.Join(*outDir, sanitize(sc.ID))
		_ = os.MkdirAll(sub, 0o755)
		rcfg := runner.Config{
			Host: h, Port: p, OutDir: sub, S3270Path: *s3270Path,
			UseSSL: useSSL, ProfilesDir: pdir, Site: site,
		}
		fmt.Printf("[%d/%d] %s (%s) ...\n", i+1, len(files), sc.ID, sc.Platform)
		res, err := runner.Run(rcfg, sc)
		if err != nil {
			if res.ScenarioID == "" {
				res = report.Result{
					ScenarioID: sc.ID, App: sc.App, Platform: sc.Platform,
					Status: "ERROR", Error: err.Error(),
					Started: time.Now().UTC(), Finished: time.Now().UTC(),
				}
			}
			failCount++
		} else if res.Status == "FAIL" {
			failCount++
		}
		all = append(all, res)
		_ = report.WriteJSON(filepath.Join(sub, "result.json"), res)
		time.Sleep(d)
	}

	packPath := filepath.Join(*outDir, "results.json")
	_ = report.WriteJSON(packPath, all)
	mdPath := filepath.Join(*outDir, "report.md")
	_ = report.WriteMarkdown(mdPath, all)
	fmt.Printf("pack done: %d scenarios, %d fail/error, json=%s md=%s\n",
		len(all), failCount, packPath, mdPath)
	if failCount > 0 {
		os.Exit(1)
	}
}

func runReport(args []string) {
	fs := flag.NewFlagSet("report", flag.ExitOnError)
	in := fs.String("in", "", "results.json path")
	md := fs.String("md", "report.md", "Markdown output path")
	_ = fs.Parse(args)
	if *in == "" {
		fail("--in is required")
	}
	data, err := os.ReadFile(*in)
	if err != nil {
		fail("read: %v", err)
	}
	var multi []report.Result
	if err := json.Unmarshal(data, &multi); err != nil {
		var single report.Result
		if err2 := json.Unmarshal(data, &single); err2 != nil {
			fail("parse json: %v", err)
		}
		multi = []report.Result{single}
	}
	if err := report.WriteMarkdown(*md, multi); err != nil {
		fail("write md: %v", err)
	}
	fmt.Printf("wrote %s\n", *md)
}

func runWordlist(args []string) {
	fs := flag.NewFlagSet("wordlist", flag.ExitOnError)
	kind := fs.String("kind", "empid", "empid|fuzz|account")
	start := fs.Int("start", 100000, "Numeric start")
	count := fs.Int("count", 20, "How many values")
	width := fs.Int("width", 6, "Zero-pad width for empid/account")
	out := fs.String("out", "", "Output file (default stdout)")
	_ = fs.Parse(args)

	var lines []string
	switch *kind {
	case "empid", "account", "id":
		lines = util.GenerateIDs(*start, *count, *width)
	case "fuzz":
		lines = util.DefaultFuzzPayloads()
	default:
		fail("unknown kind %q (empid|account|id|fuzz)", *kind)
	}
	text := strings.Join(lines, "\n") + "\n"
	if *out == "" {
		fmt.Print(text)
		return
	}
	if err := os.WriteFile(*out, []byte(text), 0o644); err != nil {
		fail("write: %v", err)
	}
	fmt.Printf("wrote %d lines to %s\n", len(lines), *out)
}

func runEbcdic(args []string) {
	fs := flag.NewFlagSet("ebcdic", flag.ExitOnError)
	in := fs.String("in", "", "Input file")
	out := fs.String("out", "", "Output file")
	to := fs.String("to", "ascii", "ascii|ebcdic")
	_ = fs.Parse(args)
	if *in == "" || *out == "" {
		fail("--in and --out required")
	}
	raw, err := os.ReadFile(*in)
	if err != nil {
		fail("read: %v", err)
	}
	var converted []byte
	switch *to {
	case "ascii":
		converted = util.EBCDICToASCII(raw)
	case "ebcdic":
		converted = util.ASCIIToEBCDIC(raw)
	default:
		fail("--to must be ascii or ebcdic")
	}
	if err := os.WriteFile(*out, converted, 0o644); err != nil {
		fail("write: %v", err)
	}
	fmt.Printf("wrote %s (%d bytes)\n", *out, len(converted))
}

func sanitize(s string) string {
	s = strings.Map(func(r rune) rune {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-', r == '_':
			return r
		default:
			return '_'
		}
	}, s)
	if s == "" {
		return "scenario"
	}
	return s
}

func fail(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}
