# 06 — Privilege Escalation & Common Misconfigurations

Focus: **z/OS + RACF-class issues** most often used in public research and real assessments. ACF2/TSS have analogs — map concepts, not always commands.

> Safety: Prefer **prove-read / prove-access** over permanent privilege changes on shared systems. If you elevate, document and reverse with the customer.

---

## Access decision flow (why privesc looks different)

```
User action → subsystem → SAF → ESM (RACF/ACF2/TSS)
                              ↓
                     ACEE (credentials in address space)
```

Many escalations aim to:

1. Gain a powerful attribute (**SPECIAL**, **OPERATIONS**), or
2. Run **APF-authorized** code that can alter the in-storage ACEE / security state, or
3. **Impersonate** a privileged identity (SURROGAT), or
4. Obtain secrets that become privileged identities.

---

## 1. APF library write / APF list control

### Why it matters
APF-authorized programs may perform privileged operations (including patterns that lead to full security bypass in the session). If you can:

- **UPDATE** an existing APF library, or
- **ADD** a library you control to the APF list,

you are typically one step from system-level compromise.

### Enum (authorized)
- List APF datasets (operator command paths, SDSF, scripts, `ISRDDN APF` style approaches depending on interface)
- For each entry, check dataset profile access: looking for UPDATE/ALTER for your identity/group
- Review who can issue dynamic APF updates (`OPERCMDS` / SETPROG related resources)

### Control failures
- Application HLQs accidentally APF-authorized and group-writable
- Old libraries left APF after migrations
- Broad UPDATE on `SYS1.*` or vendor APF libs
- Operators/groups with SETPROG rights “for convenience”

### Controls that fix it
- Only system programmers UPDATE APF libs
- Audit success/failure on APF lib writes
- Minimize dynamic APF changes; monitor SETPROG
- Continuous APF inventory vs change tickets

### Public tooling (research references)
Community REXX/scripts and Metasploit mainframe payloads have demonstrated APF-based elevation patterns. Use only in lab/authorized tests; understand cleanup.

---

## 2. WARNING mode profiles

### Behavior
Profiles in **WARNING** mode allow access that would otherwise fail, while logging a warning. Useful temporarily during migrations — dangerous if left on.

### Risk
- Sensitive datasets effectively open
- Resource privileges effectively granted
- Security DB / APF-related resources in WARNING is severe

### Enum
Search/list profiles with WARNING attribute (ESM-specific commands/tools).

### Fix
Remove WARNING; fix real access lists; monitor for reintroduction.

---

## 3. SURROGAT class abuse

### What it enables
Act as another user without their password in specific subsystems:

| Pattern | Effect |
|---------|--------|
| `userid.SUBMIT` | Submit JES jobs as that user |
| `BPX.SRV.userid` | `su`-style switch in USS to that user |

### Why it is gold
If you can surrogate a privileged batch ID, security admin, or app superuser, you inherit their data plane.

### Common real-world cause
Job schedulers and middleware need surrogate rights — granted too widely (`*.SUBMIT` patterns, whole departments).

### Controls
- Explicit, minimal SURROGAT permits
- No surrogate to SPECIAL users from broad groups
- Monitor surrogate usage
- Protected/special IDs carefully designed for batch

---

## 4. BPX.SUPERUSER & UID 0 sprawl

### BPX.SUPERUSER
READ access often allows becoming USS superuser via `su`.

### UID 0
Multiple UID 0 users break accountability and expand blast radius.

### Related
| Resource | Risk |
|----------|------|
| BPX.FILEATTR.APF | Mark USS files as APF-authorized |
| BPX.DAEMON | Identity transition patterns for daemons |
| BPX.SERVER | Server privilege patterns |
| UNIXPRIV profiles | Prefer these over blanket superuser |

### Fix
- Minimize UID 0
- Prefer UNIXPRIV granular rights
- No BPX.FILEATTR.APF for general users
- Audit superuser transitions

---

## 5. OPERCMDS: system control commands

Excessive access to operator command resources can allow:

- Dynamic APF changes
- Critical system parameter changes
- Disruption (DoS) — out of scope for most PTs unless requested

**MVS.SETPROG.*** style access is particularly sensitive.

### Fix
Least privilege operator groups; separate monitor-only vs change; full command auditing.

---

## 6. TSOAUTH / TESTAUTH

If a user can run **TESTAUTH**, they may execute programs as APF-authorized. Combined with ability to place/run chosen code, this is a privilege boundary failure.

### Fix
Strict TSOAUTH; no TESTAUTH outside controlled sysprog debugging procedures.

---

## 7. Password reset / identity administration resources

Examples of dangerous facility access (RACF-oriented literature):

- Resources that allow password reset for users without high attributes
- Broader identity admin rights short of full SPECIAL

### Impact
Account takeover → lateral across people and service IDs.

### Fix
Limit to helpdesk tiered model; MFA; monitoring; time-bound roles.

---

## 8. Dataset UACC and generic profile mistakes

| Misconfig | Result |
|-----------|--------|
| UACC(READ) on broad HLQs | Data exposure |
| UACC(UPDATE) on libs | Integrity loss / privesc |
| Missing profiles + weak PROTECTALL posture | Unprotected new datasets |
| Bad generics (`**`) | Unexpected matches |

### Fix
Default deny; careful generics; continuous access certification; alert on high UACC.

---

## 9. Started tasks & PROTECTED users

Started tasks should typically:

- Map via STARTED class to specific userids
- Use **PROTECTED** userids (no password logon)
- Run least privilege (hard in practice — still minimize)

### Failures
- STC userids with passwords and interactive logon
- STC with SPECIAL
- Shared STC identities across many functions

---

## 10. Credential hunting (soft privesc)

Often easier than memory tricks:

| Source | Secrets |
|--------|---------|
| JCL / PROC libraries | Hardcoded passwords |
| USS web configs | HTTP basic, LDAP binds |
| WebSphere security XML | `{XOR}` encoded passwords (weak encoding) |
| Stash files | LDAP/HTTP related secrets |
| Spool / logs | Accidental password prints |
| DB2 / MQ configs | App credentials |
| Automation tools | Service account passwords |

**Technique:** search + decode + reuse. Report storage of secrets as a finding even if reuse fails.

---

## 11. USS-specific privesc patterns

- Writable script directories used by privileged cron-like automation
- SUID-like extended attributes mis-set
- Vulnerable setuid-root style utilities (version dependent)
- Historical product CVEs (example classes: older NetView-related issues in public CVE records — always version-verify)

Use `OMVSEnum`-style enumeration scripts carefully for readability/permission issues.

---

## 12. CICS / app breakout as privesc

Not classic “kernel” privesc, but often more important:

- Escape business transaction → CECI/CEMT
- Upload/run JCL from CICS tools when transactions allow
- Read files/TDQs with secrets
- Abuse program link to privileged programs

See [[07-CICS-IMS-DB2-Application-Testing]].

---

## 13. From USS root to RACF SPECIAL?

Public talks cover paths between UNIX privilege and ESM privilege (and the reverse). They are environment-dependent. Mentally track both planes:

| Plane | God-mode analog |
|-------|-----------------|
| USS | UID 0 / BPX.SUPERUSER |
| RACF | SPECIAL |
| Operations | OPERATIONS attribute / broad dataset power |

Owning one plane may yield data or credentials to own the other.

---

## 14. Detection ideas (for blue team notes)

Alert on:

- New SPECIAL/OPERATIONS grants
- APF list changes
- Updates to APF libraries
- SURROGAT use outside scheduler IDs
- Mass access violations
- IRR password reset activity
- Unexpected FTP JES usage
- New highly privileged connects

Purple-team these during assessments when allowed.

---

## 15. Practical escalation workflow (assessor)

```
1. LISTUSER / group connects / OMVS UID
2. Enumerate APF + write access
3. Enumerate SURROGAT
4. Enumerate FACILITY BPX.* IRR.* OPERCMDS TSOAUTH
5. Search WARNING profiles
6. Hunt credentials in reachable datasets/USS
7. Review CICS/MQ/Db2 privileges
8. Attempt least invasive proof of impact
9. Document + clean up
```

---

## Severity cheat sheet

| Condition | Typical severity |
|-----------|------------------|
| Untrusted user writes APF lib | Critical/High |
| SURROGAT to SPECIAL/security admin | Critical/High |
| BPX.SUPERUSER + path to secrets | High |
| WARNING on production data | High/Medium |
| Excessive UACC READ on PII HLQ | High/Medium |
| Clear-text TN3270 only | Medium (context) |
| Username enumeration | Low/Medium |

---

**Next:** [[07-CICS-IMS-DB2-Application-Testing]] · **Commands:** [[12-Command-Cheatsheet]]
