# 03 — Security Architecture & Controls

This is the heart of mainframe security assessment: **what good controls look like**, and **what weak controls look like**. Most findings are control failures, not exotic 0-days.

---

## Layered control model

```
┌──────────────────────────────────────────────┐
│ Governance: SoD, PAM, change control, STIG   │
├──────────────────────────────────────────────┤
│ Data-centric: classification, masking, DLP   │
├──────────────────────────────────────────────┤
│ Encryption: datasets, CF, AT-TLS, app TLS    │
├──────────────────────────────────────────────┤
│ Authorization: ESM profiles / rules          │
├──────────────────────────────────────────────┤
│ Authentication: password/phrase, MFA, certs  │
├──────────────────────────────────────────────┤
│ Platform integrity: APF, Program Control     │
├──────────────────────────────────────────────┤
│ Audit: SMF → SIEM, alerting, retention       │
└──────────────────────────────────────────────┘
```

---

## 1. SAF — System Authorization Facility

**SAF** is the z/OS interface that applications and subsystems call for security decisions.

- Apps do not (should not) implement their own parallel ACL world for system resources.
- SAF routes checks to the installed **External Security Manager (ESM)**.
- Consistent SAF usage → consistent policy and audit.

**Control check:** Critical subsystems (CICS, Db2, MQ, FTP, USS) should be configured to honor SAF/ESM, not local bypass tables (legacy local security is a classic finding).

---

## 2. External Security Managers (ESMs)

Three dominant products:

| ESM | Vendor | Admin style (simplified) |
|-----|--------|--------------------------|
| **RACF** | IBM | Profile-based resource classes; very common |
| **ACF2** | Broadcom | Rule-based (often described as more “default-deny” oriented historically) |
| **Top Secret (TSS)** | Broadcom | Department / permission / profile model |

All three provide:

1. Authentication
2. Authorization
3. Auditing integration

**Pentest note:** Techniques differ in command syntax and data structures, but **classes of issues** (excessive privilege, weak password policy, open UACC, surrogate abuse) translate.

### RACF mental model (most documented)

| Object | Purpose |
|--------|---------|
| **User** | Identity (max 8 chars traditionally for userid) |
| **Group** | Collection of users; connect users with authorities |
| **Dataset profile** | Access to datasets (files) |
| **General resource profile** | Access to resource classes (OPERCMDS, FACILITY, SURROGAT, …) |
| **Access levels** | NONE < EXECUTE < READ < UPDATE < CONTROL < ALTER |

**Important non-intuitive rule:** For many *resource privileges*, **READ access on the profile grants the privilege**, not merely “read the ACL.”

### High-impact RACF user attributes

| Attribute | Meaning |
|-----------|---------|
| **SPECIAL** | Security administration — effectively full control of RACF |
| **OPERATIONS** | Broad access to resources unless explicitly denied |
| **AUDITOR / ROAUDIT** | Audit configuration visibility / control |
| **PROTECTED** | Cannot log on with password (for started tasks ideally) |
| **UID 0** (OMVS) | USS superuser (separate from SPECIAL, but powerful) |

**SPECIAL is the new root** is a common phrase in mainframe security talks.

---

## 3. Authentication controls

### Password vs passphrase (RACF)

| Method | Typical length | Notes |
|--------|----------------|-------|
| **PASSWORD** | 1–8 (legacy default world) | Historically weak character set |
| **PASSPHRASE** | ~9–100 (policy dependent) | Stronger; not all apps support it |

Default policy historically encouraged short passwords. Strengthening often uses exits (e.g. password quality exits) and modern SETROPTS options.

### Control expectations (good)

- [ ] Password phrases preferred over 8-char passwords
- [ ] Complexity + history + minimum age + lockout tuned carefully
- [ ] **MFA** for interactive privileged users (IBM MFA for z/OS or enterprise MFA integration)
- [ ] No password = userid patterns; no shared human IDs
- [ ] Started tasks use **PROTECTED** userids (no password logon)
- [ ] Certificate identities for services where appropriate
- [ ] Revocation process for leavers; stale IDs disabled

### Common findings

- Default/well-known IDs still active (lab leftovers in real estates more often than people admit)
- Password = username
- No lockout or lockout so aggressive that testers cause outages (both are problems)
- TSO username enumeration via error messages (mitigated with options like password preprompt behaviors — verify current site config)
- Clear-text TN3270 / FTP credentials on the wire

### Offline password auditing

If RACF database (or extracts) can be read, hashes may be audited offline with specialized tools. **Control:** protect the RACF DB datasets strictly; monitor access; encrypt where architecture allows; limit who can dump/export.

---

## 4. Authorization controls (least privilege)

### Dataset protection

Good posture:

- Default protect mindset (undefined resources not world-open)
- Least privilege profiles; careful use of generics (`**`, `*`)
- **UACC(NONE)** as default for sensitive profiles
- Production data not readable by broad groups
- Separate PROD/TEST access cleanly

Bad posture:

- `UACC(READ)` or higher on sensitive data
- Profiles in **WARNING** mode (allows access, only warns)
- Excessive `ALTER` on system libraries
- World-readable security-relevant datasets

### Resource classes (sample of high-value classes)

| Class | Controls |
|-------|----------|
| **FACILITY** | Many powerful IBM facilities (BPX.*, IRR.*, etc.) |
| **UNIXPRIV** | Granular USS privileges without full UID 0 |
| **OPERCMDS** | Operator / system commands |
| **TSOAUTH** | TSO authorities (e.g. TESTAUTH) |
| **SURROGAT** | Act as another user (job submit / USS) |
| **STARTED** | Started task identity mapping |
| **APPL** | Application access |
| **JESJOBS / JESSPOOL / …** | JES-related controls |
| **CSFSERV / CSFKEYS** | Crypto services / keys |
| **VCICSCMD / CCICSCMD / …** | CICS command security (site dependent) |
| **DIMS… / IMS…** | IMS security classes (site dependent) |
| **DSNR / GDSN…** | Db2 related (site dependent) |

### Program integrity controls

| Control | Purpose |
|---------|---------|
| **APF list** | Libraries allowed to run authorized |
| **Program Control (when enabled)** | Restricts who can execute controlled programs / libraries |
| **LPA / LINKLIST hygiene** | Trusted search order libraries must be locked down |
| **Dynamic APF changes** | Who can `SETPROG` / alter APF must be tiny set |

**Golden rule:** Anyone who can **update an APF library** or **add libraries to APF** can typically achieve full system compromise.

---

## 5. USS / UNIX privilege controls

Key FACILITY resources (names are well-known in z/OS security):

| Resource | Risk if over-granted |
|----------|----------------------|
| **BPX.SUPERUSER** | `su` to UID 0 |
| **BPX.DAEMON** | Daemon identity change patterns |
| **BPX.FILEATTR.APF** | Mark USS files APF-authorized |
| **BPX.FILEATTR.PROGCTL** | Program control attributes |
| **BPX.SERVER** | Server-related privileged behaviors |
| **BPX.DEBUG** | Debug privileged processes |
| **SURROGAT BPX.SRV.userid** | Switch to another USS identity |

Also:

- Too many users with **UID 0**
- Writable program directories in PATH
- Weak permissions on `/etc`, web roots, credential files

Prefer **UNIXPRIV** granular profiles over blanket UID 0 where possible.

---

## 6. Encryption controls

### Pervasive Encryption (z14+ era narrative)

Goal: encrypt data **at rest** widely with minimal application change.

| Layer | Mechanism |
|-------|-----------|
| Dataset encryption | z/OS dataset encryption via ICSF keys |
| Coupling Facility | Encrypted CF structures (where used) |
| Network | AT-TLS, native TLS on services, VPN/segment |
| Application | Db2/IMS encryption options; app-level TLS |

### Key management

- **ICSF** + CKDS/PKDS/TKDS
- Hardware-backed keys on Crypto Express where required
- Clear separation of key admins vs data admins (SoD)
- Key backup/recovery procedures that do not weaken control

### Control checks

- [ ] Sensitive datasets encrypted (or strong compensating access + monitoring)
- [ ] TLS required for TN3270 (992), FTP (FTPS/SFTP), web, MQ channels
- [ ] AT-TLS policies enforced; weak ciphers disabled
- [ ] Keys not stored alongside encrypted data with equal access
- [ ] Quantum-safe / modern algorithm planning on newer hardware (roadmap item)

**Pentest truth:** Encryption does not fix SPECIAL-for-everyone or open UACC. It reduces bulk data theft impact when access controls fail partially.

---

## 7. Auditing & monitoring controls

### SMF (System Management Facilities)

SMF is the audit backbone. Security-relevant record types (examples; confirm site config):

- RACF-related audit records
- Dataset access violations / successes (as configured)
- TCP/IP (e.g. Type 119) and other network telemetry
- Job submission / operational events

### Good control outcomes

- [ ] Failures **and** selected successes logged for privileged resources
- [ ] SMF data protected from tampering; retention meets compliance
- [ ] Forwarding to SIEM with mainframe-aware parsers
- [ ] Alerts on: privilege grants, APF changes, SURROGAT use, mass violations, new SPECIAL
- [ ] Regular access recertification reports (users, groups, elevated attrs)

### Common failure mode

“We log everything” but nobody monitors, or logs never leave the mainframe to a correlated SOC.

---

## 8. Privileged Access Management (PAM) & SoD

| Practice | Good | Bad |
|----------|------|-----|
| Security admins | Named, MFA, logged | Shared `SECADMIN` password |
| Operations vs security | Separated | Same group does both unrestricted |
| Emergency access | Break-glass, time-bound, reviewed | Permanent firecall IDs with SPECIAL |
| Batch / scheduler IDs | Least privilege + surrogate tightly scoped | One ID submits as any user |
| Contractors | Expiry dates, limited groups | Permanent connects “for convenience” |

---

## 9. Network & perimeter controls

- Segmentation of TN3270/FTP/MQ from general user LANs where possible
- No clear-text management protocols on untrusted networks
- Ingress allowlists for NJE partners
- API gateways in front of z/OS Connect / web services
- WAF / authN for webized 3270 and business apps

---

## 10. Configuration baselines & compliance frameworks

| Framework / guide | Use |
|-------------------|-----|
| **DISA STIGs** (z/OS RACF, ACF2, TSS) | Hardening checklist goldmine |
| **CIS** / vendor benchmarks | Where available |
| **PCI DSS / HIPAA / SOX / GDPR** | Map controls to compliance evidence |
| **IBM Security Server docs** | Authoritative behavior |
| Site **security policy + ESM standards** | Local source of truth |

---

## 11. Top 10 classic z/OS security weaknesses

(Frequently cited in audit/security literature; still useful as a review list)

1. Excessive userids with no password interval / never-expiring secrets
2. Inappropriate USS superuser (UID 0) proliferation
3. Dataset profiles with UACC greater than appropriate
4. RACF database not adequately protected
5. Excessive access to APF libraries
6. General resource profiles in WARNING mode
7. Production batch jobs with excessive resource access
8. Overly broad READ on sensitive dataset profiles
9. Improper use or lack of UNIXPRIV profiles
10. Started task IDs not defined as PROTECTED

---

## 12. Control verification vs exploitation

| Control domain | Verify by… | Abuse if weak… |
|----------------|------------|----------------|
| AuthN | Policy review, MFA status, lockout | Password spray / reuse / defaults |
| Dataset AuthZ | Profile dump analysis, access tests | Read/alter sensitive data, APF write |
| Resource AuthZ | RLIST / rule review | SURROGAT, OPERCMDS, BPX abuse |
| APF integrity | APF list + ACL review | Session privilege elevation |
| Network crypto | Port/TLS review | Credential interception |
| Audit | SMF config + SIEM | Silent privilege changes |

A mature assessment reports **control gaps** even when full compromise was not demonstrated.

---

## Quick RACF inspector commands (authorized testing)

Examples used during interactive access (names may vary by authority):

```text
LISTUSER
LISTUSER userid OMVS NORACF
LISTGRP
LISTDSD DATASET('SYS1.PARMLIB') ALL
RLIST FACILITY BPX.SUPERUSER ALL
RLIST SURROGAT * 
SEARCH CLASS(FACILITY) FILTER(BPX.**)
SETROPTS LIST
```

Always stay within ROE (rules of engagement). Some enumeration itself is sensitive.

---

**Next:** [[04-Attack-Surface-and-Services]]
