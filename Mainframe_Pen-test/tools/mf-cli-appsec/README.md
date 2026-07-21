# mf-cli-appsec v0.3 — Global TN3270 app security harness

**One Windows binary for any authorized TN3270 mainframe estate** (not hard-coded to one app or one customer).

| Item | Path |
|------|------|
| **Binary** | `bin/mf-cli-appsec.exe` |
| **Version** | `v0.3.0 windows (global-tn3270)` |
| **Applicability** | [`GLOBAL.md`](GLOBAL.md) |
| **Site template** | `configs/site.example.yaml` |
| **Global scenarios** | `scenarios/global/` |
| **Login / deny profiles** | `profiles/login/`, `profiles/deny/` |

## What is global vs what you customize

| Portable (in the tool) | Per site / app (YAML data) |
|------------------------|----------------------------|
| TN3270 automation engine | Host, port, TLS |
| IDOR / menu / vertical techniques | App codes, transaction IDs |
| Multi-ESM deny markers | Extra local deny phrases |
| Same `.exe` every engagement | `configs/mysite.yaml` + calibrated scenarios |

**Not this binary:** IBM i **5250**, pure **SSH/USS** (different protocols — see `mf-cli-appsec.exe platforms`).

## Quick start (any mainframe with TN3270)

```powershell
cd tools\mf-cli-appsec

.\bin\mf-cli-appsec.exe version
.\bin\mf-cli-appsec.exe platforms

# 1) Copy and edit site config
copy configs\site.example.yaml configs\mysite.yaml
#    set host, port, platform: ibm-zos | generic-tn3270 | ...

# 2) Validate global pack
.\bin\mf-cli-appsec.exe run --config configs\mysite.yaml `
  --scenario scenarios\global\01_smoke_connect_login.yaml --dry-run

# 3) Live (TEST only)
$env:MF_USER = "TESTID"
$env:MF_PASS = "***"
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml `
  --dir scenarios\global --recursive --out out\global-pack
```

## Colleague path (wc3270) + this tool

```text
wc3270  → explore logon + application list + business screens
     ↓
edit scenarios/global roles + steps
     ↓
mf-cli-appsec.exe + s3270.exe → automated security pack
```

## New in v0.3

- `--config` site YAML (host/ssl/profiles reusable across all scenarios)
- **Login profiles** + **deny profiles** (swap without code changes)
- **`scenarios/global/`** templates for any estate
- `--recursive` + `--tags` on `run-pack`
- `platforms` command documents coverage honestly
- `type_field`, `assert_any_contains`, generic ID wordlists

## Rebuild

```powershell
.\scripts\build.ps1
```

## Docs

- Methodology: `../../13-Console-CLI-Application-Security-Testing.md`
- Usage guide: `../../14-mf-cli-appsec-Usage-Guide.md`
- Global design: `GLOBAL.md`
