package scenario

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Scenario is a declarative console-app security test.
// Designed to be site-agnostic: set platform/protocol + profiles, inject roles,
// keep steps as pure TN3270 keystroke semantics usable on any 3270 mainframe estate.
type Scenario struct {
	App          string `yaml:"app"`
	ID           string `yaml:"id"`
	Name         string `yaml:"name"`
	SeverityHint string `yaml:"severity_hint"`
	Description  string `yaml:"description"`

	// Protocol: tn3270 (only protocol implemented in v0.3). Validated at run.
	Protocol string `yaml:"protocol"`
	// Platform: free label for reports — ibm-zos | ibm-zvm | generic-tn3270 | cics | ...
	Platform string `yaml:"platform"`
	// Tags for filtering packs (e.g. smoke, idor, authz, menu).
	Tags []string `yaml:"tags"`

	// LoginProfile / DenyProfile override site defaults (profile file IDs).
	LoginProfile string `yaml:"login_profile"`
	DenyProfile  string `yaml:"deny_profile"`
	// Extra deny markers for this scenario only.
	DenyMarkers []string `yaml:"deny_markers"`

	Roles    map[string]string `yaml:"roles"`
	Defaults Defaults          `yaml:"defaults"`
	Steps    []Step            `yaml:"steps"`
}

type Defaults struct {
	User     string `yaml:"user"`
	Password string `yaml:"password"`
}

// Step is one automation action.
//
// Actions (v0.3 — global TN3270 harness):
//
//	connect, disconnect, login, select_app, string, enter, pf, pa, clear,
//	wait, tab, backtab, tab_to, erase_eof, home, move_cursor, snapshot,
//	snap_save, assert_contains, assert_not_contains, assert_denied,
//	assert_any_contains, type_field, pause, comment
type Step struct {
	Action  string `yaml:"action"`
	Text    string `yaml:"text,omitempty"`
	Name    string `yaml:"name,omitempty"`
	Role    string `yaml:"role,omitempty"`
	Label   string `yaml:"label,omitempty"`
	Key     string `yaml:"key,omitempty"`
	Seconds int    `yaml:"seconds,omitempty"`
	MS      int    `yaml:"ms,omitempty"`
	// Profile forces a specific login profile on this login step only.
	Profile string `yaml:"profile,omitempty"`
	// Markers optional per-assert override (comma-separated not used; use list via deny_markers on scenario).
	// For assert_any_contains, Text may be "a|b|c" alternatives.
}

func Load(path string) (Scenario, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return Scenario{}, err
	}
	var sc Scenario
	if err := yaml.Unmarshal(raw, &sc); err != nil {
		return Scenario{}, fmt.Errorf("yaml: %w", err)
	}
	if sc.ID == "" {
		sc.ID = strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	}
	if sc.Protocol == "" {
		sc.Protocol = "tn3270"
	}
	if sc.Platform == "" {
		sc.Platform = "generic-tn3270"
	}
	if len(sc.Steps) == 0 {
		return Scenario{}, fmt.Errorf("scenario has no steps")
	}
	return sc, nil
}

// ListYAML lists scenario files. If recursive, walks subdirectories
// (skips names starting with _ and folders named examples-disabled).
func ListYAML(dir string, recursive bool) ([]string, error) {
	if !recursive {
		return listYAMLFlat(dir)
	}
	var out []string
	err := filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		base := d.Name()
		if d.IsDir() {
			if strings.HasPrefix(base, "_") || base == "disabled" {
				return filepath.SkipDir
			}
			return nil
		}
		n := strings.ToLower(base)
		if strings.HasSuffix(n, ".yaml") || strings.HasSuffix(n, ".yml") {
			out = append(out, path)
		}
		return nil
	})
	return out, err
}

func listYAMLFlat(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		n := strings.ToLower(e.Name())
		if strings.HasSuffix(n, ".yaml") || strings.HasSuffix(n, ".yml") {
			out = append(out, filepath.Join(dir, e.Name()))
		}
	}
	return out, nil
}

// FilterByTags keeps scenarios that contain ANY of the required tags (if tags non-empty).
func FilterByTags(files []string, tags []string) ([]string, error) {
	if len(tags) == 0 {
		return files, nil
	}
	need := map[string]struct{}{}
	for _, t := range tags {
		need[strings.ToLower(strings.TrimSpace(t))] = struct{}{}
	}
	var out []string
	for _, f := range files {
		sc, err := Load(f)
		if err != nil {
			continue
		}
		for _, t := range sc.Tags {
			if _, ok := need[strings.ToLower(t)]; ok {
				out = append(out, f)
				break
			}
		}
	}
	return out, nil
}
