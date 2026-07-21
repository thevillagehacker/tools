# 13 — Console / CLI Application Security Testing (Mainframe)

> **Purpose:** How to security-test **business applications** that run only on a console (TN3270 green-screen, TSO command apps, ISPF dialogs, CICS/IMS transactions, USS CLI tools) — not web UIs.  
> **Audience:** Assessors and app owners who need an A→Z approach for *application* risk on z/OS-style estates.  
> **Companions:** [[07-CICS-IMS-DB2-Application-Testing]], [[05-Pentest-Methodology]], [[12-Command-Cheatsheet]], toolkit under `tools/mf-cli-appsec/`.  
> **Rule:** Authorized testing only. Prefer TEST/QA. Never lock out PROD users or corrupt live money movement without explicit change control.

---

## 1. What you are actually testing

On a mainframe, “CLI / console apps” usually means one or more of:

| App style | Where it runs | How users interact |
|-----------|---------------|--------------------|
| **3270 menu / screen app** | CICS, IMS TM, custom VTAM APPL | Type fields, PF keys, clear screen, transaction codes |
| **TSO command / CLIST / REXX** | TSO READY / ISPF option 6 | Commands + arguments, like a Unix CLI |
| **ISPF dialog / panel app** | ISPF | Panels, tables, primary commands |
| **USS CLI tool** | OMVS / SSH | Familiar shell binaries/scripts |
| **Session manager front door** | TPX / similar | Menu of apps after logon |
| **Batch “app”** | JES via JCL / scheduler | Parameters in cards / control files (still testable) |

These apps are still full applications: they have **identity, authorization, business rules, data stores, and abuse cases**. Security testing is **not** only “get SPECIAL.” App-layer bugs often create more business damage than a system privesc.

```
User ──TN3270/SSH──► Terminal / Session manager
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           TSO/ISPF      CICS/IMS     USS CLI
              │            │            │
              └──── SAF/ESM + app logic ┘
                           │
                    Datasets / Db2 / MQ / VSAM / files
```

### Platform vs application testing

| Layer | Focus | Covered mainly in |
|-------|--------|-------------------|
| **Platform** | RACF, APF, SURROGAT, FTP/JES, clear-text TN3270 | Notes 03–06, 12 |
| **Application** | Wrong customer data, admin functions, injection into backend, weak app auth, business logic | **This note** + 07 |

Do both. An app can be “secure at RACF” and still let teller A read customer B’s account.

---

## 2. Types of security testing you can (and should) run

Think in **test types**, then map each to console techniques.

### 2.1 Authentication testing
- Default / weak / reused credentials for the **app** (not only TSO)
- Password = userid patterns on app logon panels
- Multi-factor bypass (if app has its own second factor)
- Logon enumeration (different messages for valid/invalid user)
- Session fixation / leftover session after logoff
- Shared generic app users (`CICSUSER`, branch operator IDs)
- Bypass of logon by jumping to a deep transaction/screen

### 2.2 Authorization / access control (most important for CLI apps)
- **Horizontal IDOR:** user A accesses user B’s customer/account/case by changing an ID field
- **Vertical privilege:** clerk reaches supervisor/admin menu or PF-key path
- **Function authorization:** transaction/command allowed without ESM or app role check
- **Object authorization:** file/VSAM/Db2 row access only UI-hidden, not server-enforced
- Role matrix violations (maker/checker, dual control)

### 2.3 Session & terminal security
- Timeout / reconnect behavior
- Whether screen retains sensitive data after clear/logoff
- Multi-session same userid policies
- Hidden / non-display fields readable via modified emulator
- Print / spool / clipboard leakage from the terminal client

### 2.4 Input validation & injection
Console apps still take untrusted input: account numbers, names, amounts, free-text notes, file names, SQL-ish search fields, USS paths.

Test for:
- Buffer / field length abuse (overflow of app buffers — careful on PROD)
- Unexpected characters (`' " ; | & < > % _ *` EBCDIC variants)
- Command injection if app shells out to USS or builds JCL/CLIST dynamically
- SQL injection via search screens into Db2
- Path / dataset name injection (`USERID.JCL` vs `SYS1.PARMLIB` style confusion)
- Format string / control character abuse in print paths

### 2.5 Business logic testing
- Negative amounts, zero amounts, overflow money fields
- Workflow skips (approve without submit, reverse without auth)
- Race / double-submit (two sessions, same payment)
- Time/date boundary (backdating)
- Limit bypass (daily transfer cap in UI only)
- Maker-checker: same user both roles

### 2.6 Data exposure & privacy
- Over-broad list screens (shows all customers)
- Error messages leaking internal IDs, SQL, dataset names
- Spool/report files world-readable
- Logs containing PAN/PII/passwords
- Canary data visible across tenants/branches

### 2.7 Cryptography & secrets (app-owned)
- Passwords in clear on screen or in datasets
- Hardcoded keys in load modules / REXX / JCL
- Weak “encryption” (XOR, ROT, trivial)
- Stash files / config members readable by app users

### 2.8 Resilience / abuse (only if scoped)
- Lockout storms (usually **out of scope** unless requested)
- Resource exhaustion via mass transactions (CPU/cost finding)
- Malformed 3270 data streams (research; careful)

### 2.9 Configuration & deployment review
- Debug transactions left on (CEDF, CECI, CEMT-class admin)
- Test menus in PROD
- Verbose diagnostics
- Weak APPLID isolation (TEST app reachable from PROD network)

### 2.10 Compliance / control mapping (optional workstream)
Map findings to org policy, PCI DSS (if cards), SOX dual control, local privacy law — not a substitute for technical tests, but useful for report priority.

---

## 3. Reference application (work through A→Z)

Use a concrete mental model. We will test a fictional but realistic app:

### **CORP-PAY** — Internal payroll inquiry & adjustment (console only)

| Item | Detail |
|------|--------|
| Access | TN3270 → session manager → APPLID `PAYT` (TEST) / `PAYP` (PROD) |
| Runtime | CICS region + COBOL programs + VSAM + Db2 |
| Users | `PAYCLERK`, `PAYSUPER`, `PAYADMIN`, HR self-service IDs |
| Main functions | Employee search, pay slip view, one-time adjustment, approve adjustment, export report to dataset |
| Controls expected | RACF transaction security + app role table; dual control on adjustments > threshold |

You can substitute your real app names; the **test catalog stays the same**.

---

## 4. A→Z testing playbook (CORP-PAY style)

### A — Agree scope & safety

**Do:**
- List APPLIDs, environments (TEST only?), user roles provided, forbidden actions (no real salary change in PROD)
- Define **canary employees** (test staff records) and **canary amounts**
- Lockout policy, max transactions/hour, emergency contact
- Data handling rules (no full employee dumps offsite)

**Deliverable:** signed ROE + test account matrix.

---

### B — Build the application map

Map like a web app site-map, but for screens/commands.

| Artifact | How |
|----------|-----|
| Entry path | x3270 screenshots from clear screen → logon → main menu |
| Transaction / command list | Manual + CEMT (if allowed) + docs + Nmap `cics-enum` (careful) |
| Screen inventory | Name each screen: `SCR-LOGIN`, `SCR-SEARCH`, `SCR-DETAIL`, `SCR-ADJ`, `SCR-APPROVE` |
| Field inventory | Row/col, length, protected?, numeric?, hidden? |
| Trust boundaries | What is checked in CICS vs COBOL vs Db2 vs RACF |
| Data stores | VSAM file names, Db2 tables, output datasets |

**Field map example (screen dump annotation):**

```
SCR-SEARCH (PAYS)
 Row 5  Col 20  EMPID     len=8   unprotected  numeric
 Row 6  Col 20  LASTNAME  len=20  unprotected  text
 Row 8  Col 20  BRANCH    len=4   unprotected  text
 PF3=Back  PF5=Search  PF7/8=Scroll  PF10=Export
```

**Why:** You cannot systematically test IDOR or authZ without knowing every identifier field and every privileged PF-key.

---

### C — Capture baseline with two+ roles

Log on as:
1. Low privilege (`PAYCLERK`)
2. Higher privilege (`PAYSUPER`)
3. If possible, peer user in another branch (`PAYCLERK2`)

For each role, record:
- Menus visible
- Transactions accepted vs rejected
- Sample successful business flow (search → view pay slip)

**Why:** Diffing role A vs B is the fastest way to find vertical privilege bugs.

---

### D — Authentication tests

| Test ID | Action | Expected secure result | Finding if fails |
|---------|--------|------------------------|------------------|
| AUTH-01 | Empty password | Deny | Auth bypass risk |
| AUTH-02 | Password = userid | Deny (policy) | Weak auth |
| AUTH-03 | Valid user, wrong pass × N | Lock or delay | DoS/lockout note |
| AUTH-04 | Invalid user vs valid user messages | Generic error | Username enum |
| AUTH-05 | Jump to `PAYS` without CESN/logon | Deny | Auth bypass |
| AUTH-06 | Logoff then PF3/redisplay | No residual PII | Session residue |
| AUTH-07 | Reuse captured session / reconnect | Re-auth required | Session weakness |

**How (manual):** x3270 + notes.  
**How (automated):** `mf-cli-appsec` scenarios or s3270 scripts (see §7).

---

### E — Authorization matrix (the heart of console app PT)

Build a table:

| Function | Clerk | Super | Other-branch clerk | Unauth |
|----------|:-----:|:-----:|:------------------:|:------:|
| Search own branch | ✓ | ✓ | ✗ | ✗ |
| View any employee | ✗ | ✓ | ✗ | ✗ |
| Create adjustment | ✓ | ✓ | ✗ | ✗ |
| Approve adjustment | ✗ | ✓ | ✗ | ✗ |
| Admin config menu | ✗ | ✗ | ✗ | ✗ |
| Export full payroll file | ✗ | limited | ✗ | ✗ |

Then **force** each cell:
- Type the transaction code even if menu hides it
- Type deep screen IDs if known
- Change EMPID on detail screen to peer’s ID
- Replay approve flow as clerk

**Classic CORP-PAY IDOR:**

```
1. Clerk searches EMPID=100200 (own branch, allowed)
2. On SCR-DETAIL, overwrite EMPID with 100999 (executive / other branch)
3. Press Enter / PF5 refresh
4. If pay slip shows → horizontal/vertical data breach
```

**Why this works so often:** UI lists filter by branch; detail program trusts the EMPID field from the terminal without re-check.

---

### F — Hidden field & 3270 attribute tests

3270 fields can be **hidden** or **protected**. Apps sometimes store auth tokens, prices, or role flags in non-display fields.

| Test | Method |
|------|--------|
| Reveal non-display | Modified emulator / research tooling (BIRP-class), or s3270 field query |
| Overwrite protected | Client that ignores protect attribute (authorized research) |
| Tamper length | Send longer than screen field (protocol level) |

**Finding class:** client-enforced security (server must revalidate).

Public talks (e.g. DerbyCon / Sensepost style 3270 research) cover field attribute abuse — use only in scope; prefer TEST.

---

### G — Input validation & injection catalog

For **every writable field**, run a small payload set (EBCDIC-safe first):

| Payload class | Examples | Looking for |
|---------------|----------|-------------|
| SQL | `' OR '1'='1`, `';--`, `1 OR 1=1` | Odd Db2 errors, extra rows |
| Delimiter | `\|`, `&&`, `;`, `/*` | Parser breaks |
| Path / DSN | `../`, `SYS1.PARMLIB`, `USER.**` | Wrong file access |
| Format | `%s%s%s`, long `AAAA…` | Crashes / weird dumps |
| Amount logic | `-1`, `0`, `999999999`, `0.001` | Business abuse |
| Unicode/EBCDIC oddities | special `@#$` | Filter bypass |

**CORP-PAY search field:** if LASTNAME is concatenated into SQL, classic injection may return all employees.

**CORP-PAY export path:** if export dataset name is user-controlled:

```
USERID.PAY.OUT
vs
SYS1.SOMETHING   (should fail)
vs
PAYADMIN.SECRET.DATA  (authZ test)
```

---

### H — Business logic deep dives

Worked examples for CORP-PAY:

1. **Dual control bypass**  
   - Clerk creates adjustment.  
   - As same clerk, try approve transaction `PAYA` directly.  
   - Try approve from second session before first commits.

2. **Threshold bypass**  
   - Adjustment limit 1000 for clerk.  
   - Submit 1000.01, or 999.99 × two times, or change amount on approve screen.

3. **Negative pay**  
   - Adjustment of negative salary / reverse sign.

4. **Workflow skip**  
   - Land on SCR-APPROVE with forged adjustment ID from another user.

5. **Time abuse**  
   - Backdated effective date to closed payroll period.

---

### I — Transaction / command enumeration

| Surface | Technique |
|---------|-----------|
| CICS | Try common 4-char codes; docs; `cics-enum`; CEMT if authorized |
| TSO app | `cmd ?`, `HELP`, intentional bad args for usage text |
| ISPF | Primary command line fuzz; jump to panel IDs |
| USS | `--help`, empty args, `strings` on binary if you can download |

**Dangerous if exposed to normal users (examples from public literature — region dependent):**  
admin/inquiry tools akin to CEMT/CECI/CEDF classes — treat any admin-style tran as critical.

---

### J — Backend authorization proof

When the screen allows an action, verify **where** it was enforced:

| Check | How |
|-------|-----|
| RACF transaction profile | `RLIST TCICSTRN PAYS AUTH` (names vary by site) |
| Dataset on export | `LISTDSD` on output HLQ |
| Db2 grants | With DBA: privileges of app auth ID |
| Surrogate batch | Export job USER= on JOB card |

**Finding quality:** “UI hid the button” is weak. “RACF allows TCICSTRN PAYA for all authenticated CICS users” is strong.

---

### K — Error handling & information disclosure

Force errors:
- Invalid EMPID formats  
- Db2 down simulation only if allowed  
- Unauthorized access  

Collect messages like:

```
DSNT408I SQLCODE = -551 ...
DATASET 'HR.PAYROLL.MASTER' NOT AUTHORIZED
PROGRAM PAYDTL ABEND ASRA
```

**Why:** Aids further exploitation and is often a finding itself in regulated environments.

---

### L — Logging, audit & non-repudiation

Ask/observe:
- Is every adjustment written to SMF / app audit file?
- Can clerk disable audit?
- Can super delete audit records from an app menu?
- Do failed IDOR attempts log?

**Purple-team angle:** perform a canary IDOR and ask SOC if it alerted.

---

### M — Multi-session & concurrency

- Two x3270 sessions as same user  
- Clerk session + super session racing one adjustment ID  
- Leave session idle past timeout, then submit  

---

### N — Data export & exfil paths (as the app user)

Apps often create the real breach channel legally:

| Path | Test |
|------|------|
| PF10 Export | Who can read the output dataset? |
| Report to spool | Who can browse job output in SDSF? |
| IND$FILE / emulator transfer | Is bulk download possible? |
| FTP of export HLQ | Post-auth FTP with same userid |

Prove with **canary employee only**.

---

### O — Secrets in the application ecosystem

Search (authorized) in:
- JCL that starts the region  
- REXX drivers  
- Control cards  
- USS configs for any bridge  
- Message queues  

Patterns: `PASSWORD=`, `PWD=`, `SECRET=`, Db2 bind plans with high priv.

---

### P — Privilege escalation *through the app*

Not platform SPECIAL — **app admin**:

- Clerk → super via parameter tampering  
- Access PAYADMIN config to grant self a role  
- Upload/replace a helper program if app has that feature  
- Abuse CECI-like interface to read files  

Then ask: does app admin imply platform power (e.g. can submit arbitrary JCL)?

---

### Q — Regression / negative tests after fixes

When developers “fix” IDOR by hiding the field:
- Retest direct EMPID overwrite  
- Retest transaction invoke without menu  
- Retest export dataset names  

---

### R — Report with business impact language

For CORP-PAY IDOR:

| Field | Example |
|-------|---------|
| Title | Horizontal authorization bypass on employee pay-slip detail |
| Severity | High / Critical (PII + compensation data) |
| Steps | Role, screens, EMPID change, screenshot |
| Impact | Any clerk can read executive compensation |
| Fix | Server-side re-authz on EMPID; bind branch from ACEE/DB; remove client trust |
| Verify | Same steps fail with clear access error + audit event |

---

### S–Z — Engagement close-out checklist

| Letter | Item |
|--------|------|
| **S** | Screenshots + screen recordings redacted |
| **T** | Transaction list & field maps archived |
| **U** | Users/passwords rotated if shared test IDs |
| **V** | Residual jobs/datasets from testing cleaned |
| **W** | Walkthrough with app owner + security |
| **X** | Cross-map to platform findings (note 05/06) |
| **Y** | Year-later retest plan (automation pack) |
| **Z** | Zero open questions: document unknowns |

---

## 5. How testing differs by console app type

### 5.1 CICS / IMS green-screen
- Test **transaction codes** + **COMMAREA/screen fields** + **TSQ/TDQ** if reachable  
- Tools: x3270, BIRP, CICSpwn (research), Nmap cics-*, custom s3270  
- AuthZ often split: RACF TCICSTRN + internal tables — test both  

### 5.2 TSO command-line apps
Treat like Unix CLI + mainframe auth:

```text
TSO> PAYAPP SEARCH EMPID(100200)
TSO> PAYAPP SHOW EMPID(100999)      /* IDOR */
TSO> PAYAPP ADJUST EMPID(100200) AMT(5000)
TSO> PAYAPP APPROVE REQ(R0001)
TSO> PAYAPP EXPORT DSN('USER.OUT')
```

Fuzz arguments; try `EXEC` of unexpected datasets; check if command is APF-authorized accidentally.

### 5.3 ISPF panel apps
- Panel-to-panel jumps  
- Primary commands  
- Table row selection tampering  
- LIBDEF / dataset concatenation tricks if app allows dataset overrides  

### 5.4 USS CLI apps
Standard CLI appsec **plus** z/OS:

```bash
./paycli --empid 100999
./paycli --file /etc/passwd
./paycli --file "//'SYS1.PARMLIB(IEASYS00)'"   # dataset notation variants
```

Check setuid-like extattr, world-writable configs, secrets in env.

### 5.5 Batch-only “apps”
Security test the **control interface**:
- Who can submit the job  
- Who can alter control cards  
- SURROGAT on privileged batch ID  
- Output dataset UACC  

---

## 6. Manual testing toolkit (day one)

| Tool | Role |
|------|------|
| **x3270 / c3270 / wc3270** | Interactive testing, screenshots |
| **s3270** | Headless automation (scriptable) |
| **Second userid** | Horizontal tests (mandatory) |
| **Notepad / Obsidian** | Field maps, evidence |
| **FTP/SFTP client** | Export path validation |
| **ISPF 3.4 / SDSF** | Side effects on datasets/spool |
| **Burp** | Only if any web front-end exists |
| **BIRP / research 3270 tools** | Field attribute testing (authorized) |

### s3270 mini pattern (manual automation)

```text
# script.s3270 — conceptual
Connect(<IP>)
Wait(InputField)
String("TSO")
Enter()
# ... logon sequence ...
String("PAYS")
Enter()
Ascii()          # dump screen for evidence
```

```bash
s3270 -script < script.s3270
```

---

## 7. Automation strategy (recommended architecture)

Console app security testing automation is best as a **driver + scenarios + report**, not one mega exploit.

```
┌─────────────────────────────────────────────┐
│  mf-cli-appsec (Go binary per OS)           │
│  - load YAML scenarios                      │
│  - drive s3270 / SSH / raw checks           │
│  - emit JSON/Markdown findings              │
└───────────────┬─────────────────────────────┘
                │
     ┌──────────┼──────────┐
     ▼          ▼          ▼
  s3270      SSH/USS     local utils
  (TN3270)   (CLI apps)  (wordlists, ebcdic, reports)
```

### Why Go for the harness
| Benefit | Detail |
|---------|--------|
| Platform-independent source | Build Windows/macOS/Linux binaries |
| Single static-ish binary | Easy to drop on assessor laptop |
| Good concurrency | Parallel scenario runners (rate-limited) |
| Easy CI | `go test` + scenario packs per app |

### Why still depend on s3270
Pure TN3270 in every language is fragile. **s3270** is battle-tested. Go orchestrates; s3270 speaks 3270.  
Alternatives: IBM **tnz** (Python), **py3270**, Robot Framework Mainframe3270, **3270Connect** (Go ecosystem).

### What to automate vs keep manual

| Automate | Keep manual / expert |
|----------|----------------------|
| Login smoke tests | Novel business logic abuse |
| Role menu diffs | Complex multi-step fraud |
| EMPID IDOR wordlist loops | Social / process controls |
| Regression after patch | Subtle dual-control races |
| Screen evidence capture | Impact storytelling |

---

## 8. Scenario pack example (YAML)

Prefer **global templates**, then a per-app pack:

| Path | Role |
|------|------|
| `tools/mf-cli-appsec/scenarios/global/` | Portable smoke / menu / IDOR / vertical (any TN3270 estate) |
| `tools/mf-cli-appsec/scenarios/corppay/` | Worked **example** of a filled-in app pack |
| `tools/mf-cli-appsec/configs/site.example.yaml` | Host/port/ssl/profiles — retarget without code changes |
| `tools/mf-cli-appsec/profiles/` | Login + multi-ESM deny markers |
| `tools/mf-cli-appsec/GLOBAL.md` | Global design + out-of-band protocols |

```yaml
# scenarios/global/04_idor_identifier.yaml (concept)
app: ANY
id: GLOBAL-IDOR-001
protocol: tn3270
platform: generic-tn3270
tags: [idor, authz, global]
login_profile: generic-userid-password-tab
roles:
  target_id: "999999"
steps:
  - action: connect
  - action: login
  # ... calibrate navigation for your app ...
  - action: type_field
    text: "{{roles.target_id}}"
  - action: enter
  - action: assert_not_contains
    text: "SALARY"   # FAIL → finding if sensitive text appears
```

The Go runner executes steps, saves screen ASCII dumps, and opens a finding if assertions fail.

**Full CLI options and v0.3 flags:** [[14-mf-cli-appsec-Usage-Guide]].

---

## 9. Toolkit layout (v0.3 — shipped)

```text
tools/mf-cli-appsec/
├── bin/mf-cli-appsec.exe          # Windows build (v0.3 global-tn3270)
├── README.md · GLOBAL.md
├── configs/site.example.yaml
├── profiles/login/ · profiles/deny/
├── scenarios/global/              # portable pack
├── scenarios/corppay/             # example app pack
├── cmd/mf-cli-appsec/
├── internal/  (config, profile, s3270, scenario, runner, report, util)
├── wordlists/
└── scripts/build.ps1
```

### Build / run (assessor laptop)

```powershell
cd tools\mf-cli-appsec
.\scripts\build.ps1

.\bin\mf-cli-appsec.exe platforms
.\bin\mf-cli-appsec.exe run --config configs\mysite.yaml `
  --scenario scenarios\global\01_smoke_connect_login.yaml --dry-run
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml `
  --dir scenarios\global --recursive --tags smoke,menu --out out\pack
```

Requires **s3270** (from wc3270) for live TN3270. Interactive exploration still uses **wc3270**.

### On-box helpers (not Go — run on z/OS)

Keep small REXX/JCL for TSO/USS CLI apps:

| Script idea | Purpose |
|-------------|---------|
| `APPENUM` | List allowed commands / help surfaces |
| `AUTHZTEST` | Drive ID list through a TSO cmd, log allow/deny |
| `DSNPROBE` | After export, check who can read output DSN |

Go stays on the **assessor workstation**; REXX stays **on-box**.

---

## 10. Wordlists & fuzz packs (console-friendly)

`wordlists/fuzz_fields.txt` (start small):

```text
'
"
;
|
&
*
%
../
../../
OR 1=1
' OR '1'='1
0
-1
999999999
AAAAAAAAAA
```

`empid_sample.txt`: sequential IDs around known canaries only (avoid blasting real HR ranges in PROD).

---

## 11. Evidence standards (console-specific)

Each finding should include:
1. Role / userid (not password)  
2. APPLID / transaction / command  
3. Screen ID + field changed  
4. Before/after screen ASCII or screenshot  
5. Business impact sentence  
6. Expected control (RACF resource / app rule)  

Store under `out/<app>/<finding-id>/`.

---

## 12. Severity guide for console apps

| Severity | Example |
|----------|---------|
| **Critical** | Unauth access to money movement; mass PII export; dual-control fully bypassable on PROD |
| **High** | Authenticated IDOR on sensitive HR/finance; admin tran open to all; SQLi dumping tables |
| **Medium** | Branch isolation bypass low-sensitivity; verbose errors; weak session timeout |
| **Low** | Minor info leak; cosmetic auth enum |
| **Info** | Debug menus on TEST only |

Tune by data class (salary, medical, PAN).

---

## 13. Program models (how to run this as a service line)

| Model | When |
|-------|------|
| **Per-app deep dive** | Critical CICS payroll/payments |
| **App portfolio triage** | Many menus — smoke + IDOR only first |
| **Dev pipeline** | Scenario pack in CI against TEST APPLID |
| **Combined platform+app** | Classic mainframe PT engagement |

Recommended: **assumed-breach app user** on TEST LPAR with production-like security rules.

---

## 14. What we can build next (practical roadmap)

| Phase | Deliverable | Value |
|-------|-------------|--------|
| **Done (v0.3)** | Global TN3270 harness + site config + profiles + `scenarios/global` | Same `.exe` any estate |
| **Done** | Windows binary + usage note 14 | Field-ready |
| **Next** | Real scenario packs per *your* apps (copy from `global/`) | Instant regression |
| **Next** | SSH/USS runner module for pure CLI tools | Non-3270 apps |
| **Later** | Role-diff recorder (“map menus as user A/B”) | Fast vertical authZ |
| **Later** | IBM i 5250 harness (separate protocol) | AS/400 console apps |
| **Later** | Finding → report template for your firm | Delivery speed |

### What you should prepare as the customer/owner
1. List of console apps + APPLIDs + owners  
2. TEST credentials for ≥2 roles each app  
3. Canary records  
4. Which actions are forbidden even on TEST  
5. Whether automation (s3270) is allowed  

---

## 15. Quick start checklist (print this)

```text
[ ] ROE + TEST APPLID only
[ ] 2+ roles issued
[ ] Canary EMPID / account IDs
[ ] x3270 connected; screen map started
[ ] Auth tests AUTH-01..07
[ ] AuthZ matrix forced (menus + direct tran)
[ ] IDOR on every identifier field
[ ] Fuzz search/export fields
[ ] Business logic: dual control, limits, negative amounts
[ ] Export dataset ACL checked
[ ] Admin/debug trans attempted
[ ] Evidence packed; secrets redacted
[ ] Automation scenarios saved for retest
```

---

## 16. Related notes & tools

| Resource | Use |
|----------|-----|
| [[07-CICS-IMS-DB2-Application-Testing]] | Middleware patterns |
| [[12-Command-Cheatsheet]] | Platform commands during app PT |
| [[08-Tools-and-Lab-Setup]] | Emulators, Nmap NSE |
| `tools/mf-cli-appsec/` | Go runner + sample scenarios |
| IBM tnz / py3270 / s3270 | Automation backends |
| sensepost BIRP | 3270 app research |
| Robot Framework Mainframe3270 | Alt automation if team already uses RF |

---

## 17. Ethics & safety (again)

Console apps often move **real money and HR data**. 

- Prefer read/inquiry tests before update tests  
- Use canary entities for any write  
- Rate-limit automation  
- Never run mass employee enumeration on PROD to “see what happens”  
- Coordinate with mainframe ops — your test transactions may look like fraud  

---

**Prev:** [[12-Command-Cheatsheet]] · **Next:** [[14-mf-cli-appsec-Usage-Guide]] · **Index:** [[00-README]] · **Toolkit:** `tools/mf-cli-appsec/README.md`
