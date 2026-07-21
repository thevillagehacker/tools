# Global applicability — what this tool covers

## Design principle

| Layer | Portable? | Where it lives |
|-------|:---------:|----------------|
| **TN3270 keystroke engine** | Yes — any 3270 host | Go binary (`s3270` driver) |
| **Security techniques** (IDOR, vertical authZ, menu abuse, denial asserts) | Yes — universal appsec patterns | Scenario actions |
| **Logon field order** | Per site | `profiles/login/*.yaml` |
| **Denial message text** | Per ESM / language | `profiles/deny/*.yaml` + site extras |
| **Host / TLS / platform label** | Per engagement | `configs/*.yaml` |
| **App-specific menus & IDs** | Per app | `scenarios/**/*.yaml` `roles:` |

**Nothing in the engine hard-codes one bank, one LPAR, or one product.**  
CORP-PAY samples are **examples only**; production use should start from `scenarios/global/` + your `site.yaml`.

## Supported today (v0.3)

**Protocol:** `tn3270` only (via s3270/wc3270 family).

**Works for** (non-exhaustive):

- IBM **z/OS** applications (TSO, ISPF, CICS, IMS TM, custom VTAM apps)
- **Session managers** (TPX-like, custom “pick an application” menus)
- IBM **z/VM**, **z/VSE** interactive 3270 apps
- Other vendor systems that still present **IBM 3270** over Telnet/TLS

**ESM / security products:** assertions use a **global deny marker list** covering RACF-, ACF2-, and Top Secret–style messages plus generic English. Add local phrases in `extra_deny_markers`.

## Explicitly out of band (same techniques, different transport)

| Platform | Why not this binary | What to use |
|----------|---------------------|-------------|
| **IBM i (AS/400)** | **5250** protocol, not 3270 | 5250 emulators / other automation |
| **z/OS USS via SSH only** | Not TN3270 | OpenSSH + shell scripts |
| **Web-only front ends** | HTTP/HTML | Burp / browser tooling |
| **MQ / Db2 network clients** | Binary protocols | Protocol-specific tools |

Those environments still need the **same security ideas** (authZ, IDOR, dual control) described in note 13 — only the harness differs.

## How to retarget the world in 4 steps

```text
1. configs/customer-a.yaml     → host, port, ssl, platform: ibm-zos
2. profiles/login/...          → match their logon panel (or keep generic)
3. scenarios/global/*.yaml     → set roles.app_code / target_id / priv_function
4. mf-cli-appsec.exe run-pack --config ... --dir scenarios/global --recursive
```

Same `.exe` for every engagement.

## Command

```powershell
.\bin\mf-cli-appsec.exe platforms
```

prints the built-in platform catalog.
