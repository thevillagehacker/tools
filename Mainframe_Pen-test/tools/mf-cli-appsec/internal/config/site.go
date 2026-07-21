// Package config loads site-wide and platform-agnostic settings so the same
// binary can target any authorized TN3270 mainframe estate (not one hard-coded app).
package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

// Site is optional shared configuration for an engagement / LPAR family.
// Point mf-cli-appsec at it with --config so host/port/ssl/profiles are not
// retyped per scenario.
type Site struct {
	// Name is a free label (e.g. "ACME-TEST-SYSPLEX").
	Name string `yaml:"name"`
	// Protocol: tn3270 (default). Documented for future protocols.
	Protocol string `yaml:"protocol"`
	// Platform family hint for reports (ibm-zos, ibm-zvm, ibm-zvse, generic-tn3270, ...).
	Platform string `yaml:"platform"`
	Host     string `yaml:"host"`
	Port     int    `yaml:"port"`
	SSL      bool   `yaml:"ssl"`
	// Default login / deny profile IDs (files under profiles/).
	LoginProfile string `yaml:"login_profile"`
	DenyProfile  string `yaml:"deny_profile"`
	// Paths (optional overrides).
	S3270Path   string `yaml:"s3270"`
	ProfilesDir string `yaml:"profiles_dir"`
	// Extra denial markers merged into deny profile.
	ExtraDenyMarkers []string `yaml:"extra_deny_markers"`
	// Default delay between pack scenarios.
	PackDelay string `yaml:"pack_delay"`
	// Notes for operators.
	Notes string `yaml:"notes"`
}

func DefaultSite() Site {
	return Site{
		Protocol:     "tn3270",
		Platform:     "generic-tn3270",
		Port:         23,
		LoginProfile: "generic-userid-password-tab",
		DenyProfile:  "global-deny",
		ProfilesDir:  "profiles",
	}
}

// LoadSite reads YAML site config. Missing file is not an error if path empty.
func LoadSite(path string) (Site, error) {
	s := DefaultSite()
	if path == "" {
		return s, nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return s, fmt.Errorf("read site config: %w", err)
	}
	if err := yaml.Unmarshal(raw, &s); err != nil {
		return s, fmt.Errorf("parse site config: %w", err)
	}
	if s.Protocol == "" {
		s.Protocol = "tn3270"
	}
	if s.Platform == "" {
		s.Platform = "generic-tn3270"
	}
	if s.Port == 0 {
		s.Port = 23
	}
	if s.LoginProfile == "" {
		s.LoginProfile = "generic-userid-password-tab"
	}
	if s.DenyProfile == "" {
		s.DenyProfile = "global-deny"
	}
	if s.ProfilesDir == "" {
		// Resolve relative to config file directory when possible.
		s.ProfilesDir = filepath.Join(filepath.Dir(path), "..", "profiles")
		if st, err := os.Stat(filepath.Join(filepath.Dir(path), "profiles")); err == nil && st.IsDir() {
			s.ProfilesDir = filepath.Join(filepath.Dir(path), "profiles")
		}
	}
	return s, nil
}

// MergeRunFlags applies CLI flags over site defaults (non-zero / non-empty win).
func (s Site) MergeHostPort(host string, port int, ssl *bool) (string, int, bool) {
	h := host
	if h == "" {
		h = s.Host
	}
	p := port
	if p == 0 {
		p = s.Port
	}
	useSSL := s.SSL
	if ssl != nil {
		useSSL = *ssl
	}
	return h, p, useSSL
}

// SupportedProtocols lists protocols this binary can drive today.
func SupportedProtocols() []string {
	return []string{"tn3270"}
}

// PlatformCatalog documents recognized platform labels (non-exhaustive).
func PlatformCatalog() map[string]string {
	return map[string]string{
		"generic-tn3270": "Any TN3270-speaking host (default; works across vendors that expose 3270)",
		"ibm-zos":        "IBM z/OS LPARs (CICS/IMS/TSO/session managers)",
		"ibm-zvm":        "IBM z/VM guest / CMS 3270 applications",
		"ibm-zvse":       "IBM z/VSE interactive applications over TN3270",
		"ibm-ztpf":       "IBM z/TPF (if TN3270 app front-end is in scope)",
		"session-manager": "Generic session manager front door (TPX-like, custom menus)",
		"cics":           "CICS-centric app pack (still TN3270)",
		"ims":            "IMS TM green-screen (still TN3270)",
		"tso-ispf":       "TSO/ISPF command/panel apps",
		// Explicit non-coverage (documented so users do not assume):
		"ibm-i-5250": "IBM i (AS/400) — uses 5250, NOT supported by this TN3270 binary",
		"ssh-uss":    "z/OS USS via SSH — use OpenSSH clients; not s3270",
	}
}

// ValidateProtocol returns error if protocol is unsupported.
func ValidateProtocol(p string) error {
	p = strings.ToLower(strings.TrimSpace(p))
	if p == "" || p == "tn3270" {
		return nil
	}
	return fmt.Errorf("protocol %q not supported by this build; supported: %v (IBM i 5250 and SSH are out of band)", p, SupportedProtocols())
}
