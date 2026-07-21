# 10 — Field Checklist & Reporting

Printable / copy-paste checklist for engagements + report structure.

---

## A. Pre-engagement checklist

- [ ] ROE signed; LPARs/IPs named
- [ ] PROD vs TEST clarified
- [ ] ESM type known (RACF/ACF2/TSS)
- [ ] Subsystems in scope listed
- [ ] Lockout policy known
- [ ] Change freeze / batch windows known
- [ ] Emergency contact 24/7
- [ ] Evidence handling rules
- [ ] Canary files / accounts created by customer (optional but excellent)

---

## B. Network & service checklist

- [ ] Full TCP scan of authorized ranges
- [ ] TN3270 ports identified; TLS vs clear-text noted
- [ ] FTP/SFTP/SSH inventory
- [ ] NJE ports / partners
- [ ] MQ listeners
- [ ] Db2 DDF ports
- [ ] Web/z/OSMF/WebSphere endpoints
- [ ] Unexpected high ports documented
- [ ] Banner/version evidence captured

---

## C. Authentication checklist

- [ ] Password policy strength (length, phrase, history)
- [ ] MFA for privileged interactive users
- [ ] Default/well-known IDs tested safely
- [ ] Username enumeration tested & documented
- [ ] Clear-text credential exposure risk
- [ ] Started tasks PROTECTED (no password logon)
- [ ] Stale userids / never-expiring secrets sampled
- [ ] Service account password storage reviewed (JCL, scripts, mid-tier)

---

## D. Authorization / ESM checklist

- [ ] Users with SPECIAL / OPERATIONS / AUDITOR listed
- [ ] UID 0 / BPX.SUPERUSER recipients listed
- [ ] APF inventory + who can write
- [ ] Who can SETPROG / alter APF dynamically
- [ ] SURROGAT grants reviewed (*.SUBMIT, BPX.SRV.*)
- [ ] WARNING mode profiles searched
- [ ] Sensitive HLQ UACC reviewed
- [ ] RACF/ESM database dataset protection
- [ ] OPERCMDS least privilege
- [ ] TSOAUTH (TESTAUTH) restricted
- [ ] UNIXPRIV used instead of blanket superuser where possible
- [ ] Batch scheduler IDs least privilege

---

## E. Subsystem checklists

### CICS
- [ ] Regions in scope mapped
- [ ] Dangerous/default transactions restricted
- [ ] Transaction security via ESM
- [ ] No broad default CICS user rights
- [ ] Gateway/web auth aligned

### IMS
- [ ] External connect auth
- [ ] Transaction / PSB least privilege

### Db2
- [ ] Privileged IDs inventoried
- [ ] App ID table privileges sampled
- [ ] TLS on distributed connections

### MQ
- [ ] CHLAUTH enabled
- [ ] MCAUSER least privilege
- [ ] TLS channels for sensitive flows

### FTP/JES/NJE
- [ ] JES-from-FTP policy appropriate
- [ ] NJE trust authenticated & minimal
- [ ] Spool access not world-readable

---

## F. Crypto & data protection checklist

- [ ] Sensitive datasets encrypted (or strong compensations)
- [ ] AT-TLS / service TLS required where applicable
- [ ] Weak ciphers disabled
- [ ] Key admin SoD
- [ ] Non-prod masking/tokenization for PII/PAN
- [ ] Backup encryption & access

---

## G. Audit & monitoring checklist

- [ ] SMF security records active for critical events
- [ ] Privileged grants logged
- [ ] APF changes logged & alerted
- [ ] Logs immutable / dual control
- [ ] SIEM ingestion + detections exist
- [ ] Incident response playbook includes mainframe

---

## H. Post-exploitation hygiene (assessor)

- [ ] Artifacts removed
- [ ] Temporary datasets deleted
- [ ] Jobs canceled/cleaned
- [ ] Privileges reverted if changed (with customer)
- [ ] Credentials rotated if exposed during test
- [ ] Evidence archive encrypted

---

## I. Report structure template

```markdown
# Mainframe Security Assessment Report

## 1. Executive Summary
- Business context
- Overall risk rating
- Top 5 findings
- Whether critical attack path to SPECIAL/data was shown

## 2. Scope & Methodology
- LPARs, IPs, subsystems
- Timeline
- Tools
- Limitations / blocked tests

## 3. Architecture Overview
- Diagram: network → services → ESM
- Trust relationships (NJE, LDAP, MQ)

## 4. Attack Path Narrative
- Step-by-step path (recon → access → escalate → impact)
- Optional alternative paths

## 5. Findings
For each finding:
- Title
- Severity
- Affected systems
- Technical description
- Evidence (redacted)
- Business impact
- Remediation
- Reference (STIG ID / IBM doc if applicable)

## 6. Control Coverage Matrix
| Domain | Status | Notes |
| AuthN | |
| AuthZ | |
| Crypto | |
| Audit | |
| PAM/SoD | |
| App/Middleware | |

## 7. Remediation Roadmap
- Immediate (0–30 days)
- Short (30–90 days)
- Strategic (90–180 days)

## 8. Appendix
- Port tables
- User/group lists (sensitive — may be separate restricted appendix)
- Tool output index
```

---

## J. Finding write-up example (style)

**Title:** Writable APF library accessible to application group  
**Severity:** Critical  
**Description:** Identity `APPUSER` via group `APPDEV` has UPDATE on `VENDOR.APF.LOAD`, which is APF-authorized.  
**Impact:** Authorized code execution in privileged state; likely full ESM compromise path.  
**Evidence:** Dataset ACL listing + APF list entry (screenshots).  
**Remediation:** Remove group UPDATE; restrict to sysprog IDs; alert on writes; review how library became group-writable.  
**Reference:** DISA STIG APF library access controls; IBM APF integrity guidance.

---

## K. Severity mapping tips

| If the finding enables… | Start at… |
|-------------------------|-----------|
| Unauth remote job exec as high-value user | Critical |
| Auth user → SPECIAL / security DB control | Critical |
| Broad PII dataset read | High |
| Clear-text admin protocol only | Medium–High (context) |
| Missing MFA for sysprogs | High (governance) |
| Info banner | Info |

Always contextualize with **data sensitivity** and **prod exposure**.

---

## L. Customer workshop agenda (readout)

1. 10 min: architecture + scope recap  
2. 15 min: attack path demo (screenshots)  
3. 30 min: top findings deep dive with sysprog + security  
4. 15 min: control roadmap  
5. 10 min: Q&A / retest plan  

Invite: security, mainframe sysprog, CICS/Db2 owners, IAM, SOC.

---

**Next:** [[11-Resources-and-References]] · **Commands:** [[12-Command-Cheatsheet]]
