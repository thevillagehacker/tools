package report

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"
)

type Result struct {
	ScenarioID   string       `json:"scenario_id"`
	App          string       `json:"app"`
	Name         string       `json:"name,omitempty"`
	SeverityHint string       `json:"severity_hint,omitempty"`
	Platform     string       `json:"platform,omitempty"`
	Protocol     string       `json:"protocol,omitempty"`
	Tags         []string     `json:"tags,omitempty"`
	Status       string       `json:"status"` // PASS | FAIL | ERROR
	Error        string       `json:"error,omitempty"`
	Findings     []Finding    `json:"findings,omitempty"`
	Steps        []StepResult `json:"steps,omitempty"`
	EvidenceDir  string       `json:"evidence_dir,omitempty"`
	Started      time.Time    `json:"started"`
	Finished     time.Time    `json:"finished"`
}

type Finding struct {
	Title    string `json:"title"`
	Detail   string `json:"detail"`
	Severity string `json:"severity"`
	Evidence string `json:"evidence,omitempty"`
}

type StepResult struct {
	Index  int    `json:"index"`
	Action string `json:"action"`
	OK     bool   `json:"ok"`
	Error  string `json:"error,omitempty"`
}

func WriteJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}

func WriteMarkdown(path string, results []Result) error {
	var b strings.Builder
	b.WriteString("# Console / CLI App Security Test Report\n\n")
	b.WriteString(fmt.Sprintf("Generated: %s\n\n", time.Now().UTC().Format(time.RFC3339)))
	b.WriteString("| Scenario | App | Platform | Status | Findings |\n")
	b.WriteString("|----------|-----|----------|--------|----------|\n")
	for _, r := range results {
		plat := r.Platform
		if plat == "" {
			plat = "-"
		}
		b.WriteString(fmt.Sprintf("| %s | %s | %s | **%s** | %d |\n",
			r.ScenarioID, r.App, plat, r.Status, len(r.Findings)))
	}
	b.WriteString("\n")

	for _, r := range results {
		b.WriteString(fmt.Sprintf("## %s (%s)\n\n", r.ScenarioID, r.Status))
		if r.Name != "" {
			b.WriteString(r.Name + "\n\n")
		}
		if r.Platform != "" || r.Protocol != "" {
			b.WriteString(fmt.Sprintf("- Platform: `%s` · Protocol: `%s`\n", r.Platform, r.Protocol))
		}
		if len(r.Tags) > 0 {
			b.WriteString(fmt.Sprintf("- Tags: %s\n", strings.Join(r.Tags, ", ")))
		}
		if r.Error != "" {
			b.WriteString(fmt.Sprintf("- Error: `%s`\n", r.Error))
		}
		b.WriteString(fmt.Sprintf("- Started: %s\n- Finished: %s\n",
			r.Started.Format(time.RFC3339), r.Finished.Format(time.RFC3339)))
		if r.EvidenceDir != "" {
			b.WriteString(fmt.Sprintf("- Evidence: `%s`\n", r.EvidenceDir))
		}
		b.WriteString("\n")
		for i, f := range r.Findings {
			b.WriteString(fmt.Sprintf("### Finding %d — %s\n\n", i+1, f.Title))
			b.WriteString(fmt.Sprintf("- Severity: **%s**\n", f.Severity))
			b.WriteString(fmt.Sprintf("- Detail: %s\n\n", f.Detail))
			if f.Evidence != "" {
				b.WriteString("```\n")
				b.WriteString(f.Evidence)
				b.WriteString("\n```\n\n")
			}
		}
	}

	b.WriteString("---\n\n*Authorized testing only. Redact credentials and regulated data before sharing.*\n")
	return os.WriteFile(path, []byte(b.String()), 0o644)
}
