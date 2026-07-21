# 14 — mf-cli-appsec Usage Guide (Windows Build)

> **Binary:** `tools/mf-cli-appsec/bin/mf-cli-appsec.exe` (**v0.3.0** windows — **global-tn3270**)  
> **Purpose:** Automate **authorized** console/CLI mainframe app security checks over TN3270 (same path as **wc3270**).  
> **Scope:** Same binary for **any** TN3270 estate (z/OS, z/VM, z/VSE, CICS/IMS/TSO, session managers). Site data is YAML, not hard-coded apps.  
> **See also:** `tools/mf-cli-appsec/GLOBAL.md` · `scenarios/global/` · `configs/site.example.yaml`  
> **Interactive twin:** explore menus with **wc3270**; automate with this tool + **s3270.exe**.  
> **Rule:** TEST/QA only unless ROE explicitly allows otherwise.

---

## 1. What the tool does (one picture)

```text
┌─────────────────────┐     YAML scenario      ┌──────────────────┐
│ mf-cli-appsec.exe   │ ─────────────────────► │ steps: login,    │
│ (this Windows build)│                        │ select_app, IDOR │
└─────────┬───────────┘                        └──────────────────┘
          │ spawns
          ▼
┌─────────────────────┐     TN3270 (23/992)    ┌──────────────────┐
│ s3270.exe           │ ─────────────────────► │ Mainframe menu   │
│ (from wc3270 pack)  │                        │ → business apps  │
└─────────────────────┘                        └──────────────────┘
          │
          ▼
   out\...\evidence\*.txt   +   result JSON/Markdown
```

| You use | For |
|---------|-----|
| **wc3270** | Human pen-test: learn screens, take screenshots, map app list by role |
| **mf-cli-appsec.exe** | Repeat those keystrokes: smoke, menu select, IDOR asserts, regression packs |
| **s3270.exe** | Headless 3270 engine (must be installed for **live** runs) |

---

## 2. Prerequisites

| Item | Required when | Notes |
|------|----------------|-------|
| `mf-cli-appsec.exe` | Always | Already built under `tools\mf-cli-appsec\bin\` |
| **wc3270** / **s3270.exe** | Live TN3270 only | Install from https://x3270.bgp.nu/ |
| Network to TEST host | Live runs | Port 23 (clear) or 992 (TLS common) |
| Test userid + password | Live logon steps | Prefer env vars `MF_USER` / `MF_PASS` |
| Calibrated YAML | Useful results | Sample scenarios are templates — edit for your app list |

### Working directory

All examples assume:

```powershell
cd C:\Users\navee\GitHub\NoteStream\Mainframe_Pen-test\tools\mf-cli-appsec
```

---

## 3. Exact end-to-end flow (recommended)

### Phase A — No mainframe yet (offline)

```powershell
# 1. Confirm binary
.\bin\mf-cli-appsec.exe version
# → mf-cli-appsec v0.3.0 windows (global-tn3270)

# 2. What platforms this binary covers
.\bin\mf-cli-appsec.exe platforms

# 3. Help
.\bin\mf-cli-appsec.exe help

# 4. Validate a GLOBAL scenario (any mainframe template)
.\bin\mf-cli-appsec.exe run `
  --config configs\site.example.yaml `
  --scenario scenarios\global\01_smoke_connect_login.yaml `
  --dry-run

# 5. See if s3270 is installed
.\bin\mf-cli-appsec.exe which-s3270
# warning if missing → install wc3270, then re-run
```

### Retarget another LPAR / customer (no code change)

```powershell
copy configs\site.example.yaml configs\customer-b.yaml
# edit host, port, ssl, platform: ibm-zos | generic-tn3270 | ...

.\bin\mf-cli-appsec.exe run-pack --config configs\customer-b.yaml `
  --dir scenarios\global --recursive --out out\customer-b
```


### Phase B — Learn the path in wc3270 (manual pen-test)

1. Open **wc3270** → connect to TEST host:port.  
2. Log on with test user.  
3. Note the **application list** (names / numbers).  
4. Select the app your role is allowed to use.  
5. Map screens, fields, PF keys, and canary IDs.  
6. Write down exact keystrokes (this becomes YAML).

### Phase C — Reachability

```powershell
# Clear-text TN3270
.\bin\mf-cli-appsec.exe probe --host YOUR.TEST.HOST --port 23

# TLS port (TCP only — does not complete TLS handshake)
.\bin\mf-cli-appsec.exe probe --host YOUR.TEST.HOST --port 992 --timeout 8s
```

Expected line:

```text
tcp YOUR.TEST.HOST:23 -> OPEN (tcp connect ok)
```

### Phase D — Live smoke (session manager flow)

```powershell
$env:MF_USER = "PAYCLERK"      # your TEST userid
$env:MF_PASS = "********"      # do not commit this

.\bin\mf-cli-appsec.exe run `
  --host YOUR.TEST.HOST `
  --port 23 `
  --scenario scenarios\corppay\session_manager_flow.yaml `
  --out out\menu-smoke
```

TLS example:

```powershell
.\bin\mf-cli-appsec.exe run `
  --host YOUR.TEST.HOST `
  --port 992 `
  --ssl `
  --scenario scenarios\corppay\session_manager_flow.yaml `
  --user PAYCLERK `
  --out out\menu-smoke-tls
```

### Phase E — Security scenarios (after calibration)

```powershell
# Single IDOR-style scenario (edit YAML first!)
.\bin\mf-cli-appsec.exe run `
  --host YOUR.TEST.HOST --port 23 `
  --scenario scenarios\corppay\idor_payslip.yaml `
  --user PAYCLERK `
  --out out\idor

# Full pack (all YAML in folder)
.\bin\mf-cli-appsec.exe run-pack `
  --host YOUR.TEST.HOST `
  --port 23 `
  --dir scenarios\corppay `
  --user PAYCLERK `
  --delay 800ms `
  --out out\corppay-pack
```

### Phase F — Read results

```text
out\corppay-pack\
  results.json          ← all scenarios
  report.md             ← human-readable pack report
  CORP-PAY-MENU-001\
    result.json
    evidence\
      01_pre_login.txt
      02_app_list.txt
      03_inside_app.txt
  ...
```

Exit codes:

| Code | Meaning |
|-----:|---------|
| `0` | PASS (or dry-run OK / report written) |
| `1` | FAIL (assertion finding) or ERROR during run-pack |
| `2` | Bad usage / missing required flags |

---

## 4. Command reference (all options)

### v0.3 upgrades (global TN3270) — documented here

| Upgrade | Where to use it |
|---------|-----------------|
| **Site config** | `--config configs\mysite.yaml` on `probe` / `run` / `run-pack` |
| **Login / deny profiles** | `profiles/login/`, `profiles/deny/` + `login_profile` / `deny_profile` in site or scenario YAML |
| **Global scenario pack** | `scenarios/global/` (prefer over CORP-PAY for new estates) |
| **`platforms` command** | Lists protocol coverage + platform labels |
| **`run-pack --recursive`** | Walk subfolders for YAML |
| **`run-pack --tags`** | Filter by scenario `tags:` (e.g. `smoke,menu,idor`) |
| **`--profiles-dir`** | Override profile root |
| **New actions** | `type_field`, `assert_any_contains` |
| **Report fields** | `platform`, `protocol`, `tags` in JSON/Markdown |
| **Design write-up** | `tools/mf-cli-appsec/GLOBAL.md` |

CORP-PAY under `scenarios/corppay/` remains a **worked example** only.

---

### 4.1 `version`

```powershell
.\bin\mf-cli-appsec.exe version
```

No options. Prints build string (expect `v0.3.0 windows (global-tn3270)`).

---

### 4.2 `help` / `platforms`

```powershell
.\bin\mf-cli-appsec.exe help
.\bin\mf-cli-appsec.exe platforms
```

`platforms` documents what this binary supports (**tn3270** only) and labels such as `ibm-zos`, `generic-tn3270`, `session-manager`, plus explicit non-coverage (IBM i 5250, SSH/USS).

---

### 4.3 `which-s3270`

Shows which `s3270` binary will be used.

| Option | Default | Description |
|--------|---------|-------------|
| `--s3270` | *(auto)* | Force full path to `s3270.exe` |

```powershell
.\bin\mf-cli-appsec.exe which-s3270
.\bin\mf-cli-appsec.exe which-s3270 --s3270 "C:\Program Files\wc3270\s3270.exe"
```

---

### 4.4 `probe` — TCP reachability

| Option | Default | Required | Description |
|--------|---------|:--------:|-------------|
| `--config` | | | Site YAML (`host`/`port` defaults) |
| `--host` | site / empty | **yes*** | Hostname or IP (*or set in config) |
| `--port` | site / `23` | | TCP port (`23`, `992`, …) |
| `--timeout` | `5s` | | Dial timeout (`3s`, `10s`, …) |
| `--s3270` | `false` | | If set, also check that s3270 binary exists |

```powershell
.\bin\mf-cli-appsec.exe probe --host 10.0.0.5 --port 23
.\bin\mf-cli-appsec.exe probe --config configs\mysite.yaml
.\bin\mf-cli-appsec.exe probe --host mf-test.example.com --port 992 --timeout 10s
.\bin\mf-cli-appsec.exe probe --host 10.0.0.5 --port 23 --s3270
```

**What you can test with `probe`:** host listening / firewall open. Not full logon.

---

### 4.5 `run` — one scenario (main command)

| Option | Default | Required | Description |
|--------|---------|:--------:|-------------|
| `--scenario` | | **yes** | Path to `.yaml` / `.yml` |
| `--config` | | | Site YAML (host, port, ssl, profiles) |
| `--host` | site | yes\* | Target host (\*not needed with `--dry-run` if only parsing) |
| `--port` | site / `23` | | TN3270 port |
| `--user` | env `MF_USER` | | Logon userid (overrides YAML `defaults.user`) |
| `--pass` | env `MF_PASS` | | Password (prefer env, not CLI history) |
| `--out` | `out/run` | | Folder for JSON + `evidence\` |
| `--s3270` | auto / site | | Path to s3270.exe |
| `--profiles-dir` | `profiles` / site | | Login + deny profile root |
| `--ssl` | site / `false` | | Use TLS tunnel prefix `L:host:port` (for 992-style) |
| `--dry-run` | `false` | | Parse YAML only; no network |

```powershell
# Parse only (global template)
.\bin\mf-cli-appsec.exe run --config configs\site.example.yaml `
  --scenario scenarios\global\01_smoke_connect_login.yaml --dry-run

# Live via site config (any estate)
.\bin\mf-cli-appsec.exe run --config configs\mysite.yaml `
  --scenario scenarios\global\02_session_menu_select.yaml `
  --user TESTID --out out\menu

# Live clear-text without config file
.\bin\mf-cli-appsec.exe run `
  --host 10.0.0.5 --port 23 `
  --scenario scenarios\global\01_smoke_connect_login.yaml `
  --user PAYCLERK --out out\smoke

# Live TLS
.\bin\mf-cli-appsec.exe run `
  --host 10.0.0.5 --port 992 --ssl `
  --scenario scenarios\global\01_smoke_connect_login.yaml `
  --user PAYCLERK --out out\smoke-tls

# Password via environment (recommended)
$env:MF_USER = "PAYCLERK"
$env:MF_PASS = "********"
.\bin\mf-cli-appsec.exe run --config configs\mysite.yaml `
  --scenario scenarios\global\04_idor_identifier.yaml --out out\idor
```

**Console output example:**

```text
status=PASS findings=0 evidence=out\smoke\evidence json=out\smoke\CORP-PAY-MENU-001.json
status=FAIL findings=1 evidence=out\idor\evidence json=out\idor\CORP-PAY-IDOR-001.json
```

---

### 4.6 `run-pack` — all scenarios in a directory

| Option | Default | Required | Description |
|--------|---------|:--------:|-------------|
| `--config` | | | Site YAML |
| `--host` | site | **yes*** | Target host (*or config) |
| `--dir` | | **yes** | Folder of YAML files |
| `--port` | site / `23` | | TN3270 port |
| `--user` | `MF_USER` | | Userid for all scenarios |
| `--pass` | `MF_PASS` | | Password for all scenarios |
| `--out` | `out/pack` | | Root output folder |
| `--delay` | `500ms` | | Pause between scenarios (rate-limit) |
| `--s3270` | auto / site | | s3270 path |
| `--profiles-dir` | `profiles` | | Profile root |
| `--ssl` | site / `false` | | TLS tunnel connect |
| `--recursive` | `false` | | Walk subdirectories for `.yaml` |
| `--tags` | | | Comma list; keep scenarios with **any** matching `tags:` |

```powershell
# Global pack (recommended starting point for any mainframe)
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml `
  --dir scenarios\global --recursive `
  --user PAYCLERK --delay 1s --out out\global-pack

# Only smoke + menu tagged scenarios
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml `
  --dir scenarios\global --recursive --tags smoke,menu `
  --out out\smoke-menu

# Example app pack (CORP-PAY samples)
.\bin\mf-cli-appsec.exe run-pack `
  --host 10.0.0.5 --port 23 `
  --dir scenarios\corppay `
  --user PAYCLERK --delay 1s --out out\corppay-pack
```

Produces:

- `out\corppay-pack\results.json`
- `out\corppay-pack\report.md`
- per-scenario subfolders with `result.json` + `evidence\`

---

### 4.7 `report` — JSON → Markdown

| Option | Default | Required | Description |
|--------|---------|:--------:|-------------|
| `--in` | | **yes** | `results.json` or single-result JSON |
| `--md` | `report.md` | | Output Markdown path |

```powershell
.\bin\mf-cli-appsec.exe report `
  --in out\corppay-pack\results.json `
  --md out\corppay-pack\retest-report.md
```

---

### 4.8 `wordlist` — generate test inputs

| Option | Default | Description |
|--------|---------|-------------|
| `--kind` | `empid` | `empid` or `fuzz` |
| `--start` | `100000` | First EMPID (kind=empid) |
| `--count` | `20` | How many EMPIDs |
| `--out` | stdout | File path if set |

```powershell
# Canary EMPID range (use only authorized IDs)
.\bin\mf-cli-appsec.exe wordlist --kind empid --start 100200 --count 10 --out wordlists\my_canaries.txt

# Field fuzz payloads
.\bin\mf-cli-appsec.exe wordlist --kind fuzz --out wordlists\fuzz_fields.txt
```

**What you can test:** feed these values into YAML `string` steps or manual wc3270 entry for IDOR / input validation.

---

### 4.9 `ebcdic` — text conversion helper

| Option | Default | Required | Description |
|--------|---------|:--------:|-------------|
| `--in` | | **yes** | Input file |
| `--out` | | **yes** | Output file |
| `--to` | `ascii` | | `ascii` (from EBCDIC) or `ebcdic` (to EBCDIC) |

```powershell
.\bin\mf-cli-appsec.exe ebcdic --in dump_ebcdic.bin --out dump_readable.txt --to ascii
.\bin\mf-cli-appsec.exe ebcdic --in note.txt --out note.ebc --to ebcdic
```

Best-effort CP037-style mapping for printable text — not a full mainframe codec.

---

## 5. Scenario YAML — structure and all actions

### 5.1 File skeleton

```yaml
app: MYAPP                      # free-text app name for reports
id: MYAPP-IDOR-001              # unique id (becomes folder/file name)
name: Short title for report
severity_hint: high             # info|low|medium|high|critical (report only)
description: >
  What this scenario proves.
roles:
  victim_empid: "100999"
  app_code: "PAYROLL"
defaults:
  user: ""                      # usually overridden by --user / MF_USER
  password: ""                  # usually overridden by --pass / MF_PASS
steps:
  - action: connect
  - action: login
  # ...
```

Placeholders in `text` fields:

| Token | Expands to |
|-------|------------|
| `{{user}}` | `defaults.user` |
| `{{roles.KEY}}` or `{{KEY}}` | `roles.KEY` value |

---

### 5.2 All step actions (what you can automate)

| Action | YAML fields | What it does | Security use |
|--------|-------------|--------------|--------------|
| `connect` | `text: ssl` optional | TN3270 connect (`--ssl` or text) | Session start |
| `disconnect` | | Drop host | Cleanup |
| `wait` | `text` mode, `seconds` | Wait for host (`InputField`, …) | Stabilize screens |
| `login` | uses defaults user/pass | Type user, Tab, pass, Enter | Auth smoke |
| `select_app` | `text` | Type app code/name + Enter | **Session-manager menu** (wc3270 path) |
| `string` | `text` | Type characters into field | IDs, search, fuzz |
| `enter` | | Enter AID | Submit screen |
| `clear` | | Clear | Reset screen |
| `tab` | `text: N` optional | Tab N times (default 1) | Move between fields |
| `backtab` | | BackTab | Field navigation |
| `erase_eof` | | Erase to end of field | Clear old EMPID before overwrite |
| `home` | | Cursor home | Navigation |
| `move_cursor` | `text: "row,col"` | Zero-origin cursor move | Precise field targeting |
| `pf` | `key: PF3` or `text: 3` | PF1–PF24 | Menus, search, export |
| `pa` | `text: 1` | PA1–PA3 | Rare AID keys |
| `snapshot` | `name` | Save ASCII screen to evidence | Proof for report |
| `snap_save` | | s3270 Snap(Save) | Consistent capture |
| `assert_contains` | `text` | **FAIL** if missing | Smoke: landed on menu |
| `assert_not_contains` | `text` | **FAIL/finding** if present | **IDOR** (salary text, etc.) |
| `assert_denied` | | **FAIL** if no deny markers | Vertical authZ expected block |
| `pause` | `ms` or `seconds` | Sleep | Slow hosts |
| `comment` | `text` | No-op note | Documentation in YAML |

#### Assertion outcomes

| Assertion | PASS means | FAIL means (tool status FAIL) |
|-----------|------------|--------------------------------|
| `assert_contains` | Expected banner/menu text seen | Navigation wrong / app down |
| `assert_not_contains` | Sensitive text **not** shown | Likely **IDOR / over-disclosure** |
| `assert_denied` | Screen shows access-denied style text | User reached privileged function |

`assert_denied` looks for markers such as:  
`NOT AUTHORIZED`, `ACCESS DENIED`, `SECURITY VIOLATION`, `ICH`, `TSS`, …

---

### 5.3 Sample scenarios shipped with the build

| File | Intent | Calibrate before trust |
|------|--------|------------------------|
| `scenarios\corppay\session_manager_flow.yaml` | wc3270 path: login → app list → select app | App code / menu number |
| `scenarios\corppay\smoke_login.yaml` | Basic login + snapshots | Logon field order |
| `scenarios\corppay\idor_payslip.yaml` | Horizontal IDOR template | EMPID field + assert text |
| `scenarios\corppay\authz_matrix.yaml` | Clerk tries privileged tran | Real approve transaction code |

---

## 6. Exact flows for common pen-test activities

### 6.1 Flow: “Connect like my colleague (app list by role)”

**Manual (wc3270):** connect → logon → see list → pick app.  
**Automated:**

```yaml
# scenarios\myapp\menu_select.yaml
app: MYAPP
id: MYAPP-MENU-001
name: Select application from session manager
roles:
  app_code: "2"          # or "PAYROLL" — YOUR menu value
steps:
  - action: connect
  - action: wait
    text: InputField
    seconds: 30
  - action: snapshot
    name: 01_banner
  - action: login
  - action: pause
    ms: 1000
  - action: snapshot
    name: 02_app_list
  - action: select_app
    text: "{{roles.app_code}}"
  - action: snapshot
    name: 03_app_home
  - action: assert_contains
    text: "MAIN MENU"    # replace with text you always see inside the app
```

```powershell
.\bin\mf-cli-appsec.exe run --host TESTHOST --scenario scenarios\myapp\menu_select.yaml --user ROLEA --out out\menu-a
.\bin\mf-cli-appsec.exe run --host TESTHOST --scenario scenarios\myapp\menu_select.yaml --user ROLEB --out out\menu-b
# Diff evidence\02_app_list.txt between roles → authorization matrix evidence
```

**What this tests:** role-based visibility of apps; ability to open selected app; landing screen correctness.

---

### 6.2 Flow: “Try an app not on my list” (menu bypass)

In wc3270 you type a hidden app name. In YAML:

```yaml
steps:
  - action: connect
  - action: login
  - action: snapshot
    name: list
  - action: select_app
    text: "PAYADMIN"       # not shown on clerk menu
  - action: snapshot
    name: after_hidden
  - action: assert_denied  # secure: should deny
  # OR if you expect it must never show admin content:
  # - action: assert_not_contains
  #   text: "ADMIN CONFIG"
```

**What this tests:** session-manager / APPL authorization gaps.

---

### 6.3 Flow: IDOR on a detail screen

```yaml
app: MYAPP
id: MYAPP-IDOR-001
name: Change EMPID to canary out of scope
severity_hint: high
roles:
  victim_empid: "100999"
steps:
  - action: connect
  - action: login
  - action: select_app
    text: "PAYROLL"
  - action: pause
    ms: 500
  # Open search / detail (site-specific):
  - action: string
    text: "PAYS"
  - action: enter
  - action: tab
    text: "2"
  - action: erase_eof
  - action: string
    text: "{{roles.victim_empid}}"
  - action: enter
  - action: pause
    ms: 500
  - action: snapshot
    name: detail_victim
  # If restricted data appears, this FAILS → finding
  - action: assert_not_contains
    text: "ANNUAL SALARY"
```

```powershell
.\bin\mf-cli-appsec.exe run --host TESTHOST --scenario scenarios\myapp\idor.yaml --user CLERK --out out\idor
```

**What this tests:** horizontal/vertical data authorization (core app PT).

---

### 6.4 Flow: vertical privilege (clerk runs super transaction)

```yaml
steps:
  - action: connect
  - action: login
  - action: select_app
    text: "PAYROLL"
  - action: clear
  - action: string
    text: "PAYA"          # approve / admin tran code
  - action: enter
  - action: snapshot
    name: priv_attempt
  - action: assert_denied
```

**What this tests:** function-level authorization (menu hide ≠ server deny).

---

### 6.5 Flow: input fuzz on a search field

1. Generate payloads:

```powershell
.\bin\mf-cli-appsec.exe wordlist --kind fuzz --out wordlists\fuzz_fields.txt
```

2. Either loop manually in wc3270, or create one YAML per payload / one scenario that steps through a few high-value payloads with snapshots after each.

**What this tests:** SQLi-ish errors, parser crashes, path injection, odd error disclosure.

---

### 6.6 Flow: regression pack after a fix

```powershell
.\bin\mf-cli-appsec.exe run-pack `
  --host TESTHOST `
  --dir scenarios\myapp `
  --user CLERK `
  --delay 1s `
  --out out\retest-2026-07-17

# Open:
#   out\retest-2026-07-17\report.md
```

**What this tests:** previous findings stay fixed; smoke still works.

---

## 7. Credentials — options ranked safely

| Method | Example | Prefer? |
|--------|---------|:-------:|
| Environment | `$env:MF_USER="A"; $env:MF_PASS="B"` | **Yes** |
| CLI flags | `--user A --pass B` | OK on locked laptop; hits shell history |
| YAML `defaults` | hard-coded password in file | **Avoid** (secret in git) |

```powershell
$env:MF_USER = "PAYCLERK"
$env:MF_PASS = "********"
# then omit --user/--pass on run / run-pack
```

---

## 8. Output layout and how to read it

### Single `run`

```text
out\smoke\
  CORP-PAY-MENU-001.json      ← status, steps, findings
  evidence\
    01_pre_login.txt
    02_app_list.txt
    03_inside_app.txt
    error_screen.txt          ← only if a hard step error occurred
```

### JSON fields (important)

| Field | Meaning |
|-------|---------|
| `status` | `PASS` / `FAIL` / `ERROR` |
| `findings[]` | Assertion failures (security signals) |
| `steps[]` | Each action OK/error |
| `evidence_dir` | Path to screen dumps |
| `error` | Hard failure message |

### Pack `report.md`

Table of all scenarios + per-finding sections for FAIL cases — attach (redacted) to engagement report.

---

## 9. Mapping tool options → pen-test catalog

| Pen-test activity | Tool support today |
|-------------------|--------------------|
| Host/port open? | `probe` |
| s3270 installed? | `which-s3270` |
| Logon works? | `run` + `login` + `snapshot` |
| App list by role | `run` twice with different `--user`; compare `snapshot` of app list |
| Select app from list | `select_app` |
| Hidden app access | `select_app` unlisted code + `assert_denied` / `assert_not_contains` |
| IDOR / field tamper | `string` + `erase_eof` + `assert_not_contains` |
| Vertical authZ | privileged `string`/tran + `assert_denied` |
| Screen evidence | `snapshot` |
| Field fuzz payloads | `wordlist --kind fuzz` (+ manual or YAML) |
| EMPID canary lists | `wordlist --kind empid` |
| EBCDIC dump readable | `ebcdic --to ascii` |
| Batch retest | `run-pack` |
| Report | `report` / pack `report.md` |
| TLS TN3270 | `--ssl` + port `992` |
| Rate-limit automation | `run-pack --delay` |

**Still mainly manual in wc3270:** novel business logic (dual control races, multi-window fraud), visual UX abuse, complex multi-hour workflows. Encode them into YAML **after** you understand them once.

---

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `start s3270 ...` error | s3270 not installed | Install wc3270; `which-s3270` |
| `timeout waiting for s3270` | Host slow / wrong wait | Raise `wait.seconds`; add `pause` |
| `login requires defaults...` | No user/pass | Set `MF_USER`/`MF_PASS` or `--user`/`--pass` |
| `status=ERROR` after connect | Wrong host/port/firewall | `probe`; try `--ssl` on 992 |
| Assertions always fail | YAML not calibrated | Snapshot first; copy real screen text into asserts |
| Garbled screen text | Charset | Explore with wc3270; match site charset later in s3270 if needed |
| Account locked | Too many bad logons | Slow `--delay`; use TEST IDs; stop spray |

---

## 11. Copy-paste checklist (first engagement day)

```powershell
cd C:\Users\navee\GitHub\NoteStream\Mainframe_Pen-test\tools\mf-cli-appsec

.\bin\mf-cli-appsec.exe version
.\bin\mf-cli-appsec.exe platforms
.\bin\mf-cli-appsec.exe which-s3270

copy configs\site.example.yaml configs\mysite.yaml
# edit host / port / platform

.\bin\mf-cli-appsec.exe run --config configs\mysite.yaml `
  --scenario scenarios\global\01_smoke_connect_login.yaml --dry-run
.\bin\mf-cli-appsec.exe probe --config configs\mysite.yaml

# Explore once in wc3270, then:
$env:MF_USER = "TESTUSER"
$env:MF_PASS = "********"
.\bin\mf-cli-appsec.exe run --config configs\mysite.yaml `
  --scenario scenarios\global\02_session_menu_select.yaml `
  --out out\day1-menu

# Calibrate roles in global YAMLs → full pack
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml `
  --dir scenarios\global --recursive --delay 1s --out out\day1-pack
```

---

## 12. Related notes

| Note | Content |
|------|---------|
| [[13-Console-CLI-Application-Security-Testing]] | A→Z methodology (what to test conceptually) |
| [[12-Command-Cheatsheet]] | Platform TSO/RACF commands (if you also get TSO) |
| [[07-CICS-IMS-DB2-Application-Testing]] | Middleware app patterns |
| `tools/mf-cli-appsec/README.md` | Short tool readme (v0.3) |
| `tools/mf-cli-appsec/GLOBAL.md` | Global applicability design |
| `tools/mf-cli-appsec/scenarios/global/README.md` | Global pack table |

---

**Binary path again:** `tools/mf-cli-appsec/bin/mf-cli-appsec.exe` (v0.3.0)  
**Index:** [[00-README]]
