# 04 — Attack Surface & Services

This note maps **what is exposed**, **why it matters**, and **what to check**.

---

## Typical TCP ports (z/OS-ish estates)

Ports vary by site. Treat this as a **hunt list**, not a guarantee.

| Port | Service / hint |
|-----:|----------------|
| 21 | FTP (dataset + USS; can submit to JES) |
| 22 | SSH (USS) |
| 23 | TN3270 / Telnet |
| 24 | Telnet (sometimes) |
| 175 | NJE (Network Job Entry) |
| 443 / 80 | IBM HTTP Server, WebSphere, z/OSMF, web 3270 |
| 515 | Print-related |
| 992 | TN3270 over TLS (common) |
| 1023 | Telnet/TN3270 alternate |
| 1414 / 1415 | IBM MQ |
| 2252 | NJE over TLS (common alternate) |
| 2809 | CORBA / WLM-ish services (environment dependent) |
| 3021+ | Db2 location ports (site-specific) |
| 32208 etc. | Various vendor / ISV listeners |
| 8803 | RMF Data Portal (sometimes) |
| many high ports | CICS regions, IMS, custom apps, monitoring |

**Notes:**

- One mainframe host may have **many IPs** (dozens possible).
- Services may sit on **unusual ports** (FTP on 900, Telnet on 1023, etc.).
- Always full-port scan authorized ranges with version detection.

---

## Network recon fingerprints

Signs you are looking at a mainframe:

- Banners containing `z/OS`, `IBM`, `FTP server (version ...)`, mainframe FTP styles
- TN3270 negotiation (not plain BSD telnet only)
- NJE listeners
- MQ + 3270 + FTP combo on same host
- EBCDIC oddities in some responses

---

## Access path map

```
                ┌──────────── TN3270 ────────────┐
Client ─────────┤                                ├─→ VTAM APPL selection
                │  TSO | CICS | IMS | TPX | other│
                └──────────── SSH/Telnet ────────┘─→ USS shell
                └──────────── FTP/SFTP ──────────┘─→ datasets / USS / JES
                └──────────── HTTP/API ──────────┘─→ WebSphere / z/OS Connect
                └──────────── MQ / Db2 client ───┘─→ data plane
                └──────────── NJE ───────────────┘─→ remote systems / jobs
```

---

## 1. TN3270 & terminal services

### What it is
Protocol for 3270 “green screen” applications over TCP (often Telnet negotiation). Modern sites should use **TLS (port 992 or AT-TLS)**.

### Clients
- **x3270 / c3270 / wc3270**
- Vendor web thin clients (Virtel, Host On-Demand, etc.)
- Commercial emulators (PCOMM, Rumba, etc.)

### Security issues
| Issue | Why it matters |
|-------|----------------|
| Clear-text sessions | Credential theft, session snooping |
| Hidden/non-display fields | Apps hide secrets in 3270 field attributes; modified emulators can reveal |
| Protected field bypass research | Historical app logic flaws |
| Weak app auth vs system auth | App passwords weaker than RACF policy |
| Session management | Shared terminals, no timeout |

### Testing ideas (authorized)
- Screenshot/banner all TN3270 ports (`tn3270-screen` Nmap script family)
- Identify whether you land in VTAM, TSO, CICS, or a session manager (TPX, etc.)
- Check TLS vs clear-text
- Observe userid enumeration differences on logon panels

---

## 2. VTAM / SNA applications

**VTAM** multiplexes access to applications (APPLIDs). After TN3270 connect, users often type a logon command / select an app.

Examples of destinations:

- TSO
- CICS regions (multiple)
- IMS
- Session managers
- Other LPARs via network definitions

### Enum
- Nmap `vtam-enum`, `lu-enum` style scripts (community)
- Manual exploration with x3270
- Note APPLID naming conventions (often reveal env: `CICSPROD`, `CICSTEST`)

### Control checks
- Only required APPLIDs exposed
- Appl logon restricted via ESM APPL class / session manager policies
- No debug/admin apps reachable from broad networks

---

## 3. TSO / ISPF

| Component | Role |
|-----------|------|
| **TSO/E** | Interactive command environment |
| **ISPF** | Panel-driven productivity facility |
| **SDSF / equivalent** | Job and system display (authority-sensitive) |

### Why attackers want TSO
- Submit jobs
- Browse datasets
- Run REXX
- Enter OMVS
- Issue security query commands (if permitted)

### Controls
- Who has TSO segment / logon rights
- TSOAUTH resources
- Account lockout / preprompt options
- ISPF/TSO command restriction policies

---

## 4. FTP and file movement

z/OS FTP is unusually powerful:

- Access **datasets** and **USS** files
- Support for site-specific commands
- Can switch into **JES mode** so uploaded files are treated as jobs

### Risks
| Risk | Detail |
|------|--------|
| Credential brute force | Common remote service |
| JES submission | Remote code/job execution as that user |
| Data exfil | Bulk download of datasets |
| Clear-text FTP | Credential + data exposure |
| Broad dataset access | FTP rights follow ESM dataset rules — still dangerous if user is overprivileged |

### Safer alternatives
- **SFTP** / **FTPS**
- Managed file transfer products with strong authZ and logging

### Control checks
- TLS required
- JES interface restricted / monitored
- Banner hardening; no unnecessary anonymous
- Strong authN; MFA for interactive where applicable
- Dataset rules actually least privilege

---

## 5. JES2 / JES3 (batch)

Everything is a **job** eventually.

```
Submit (TSO/FTP/NJE/scheduler) → JES spool → execution → output spool
```

### Security angles
- Who can submit jobs
- Who can read job output (may contain secrets)
- Job class / priority abuse
- Surrogate submission (`USER=` on JOB card with SURROGAT rights)
- Scheduler identities (Control-M, CA7, etc.) over-permissioned

---

## 6. NJE (Network Job Entry)

Connects mainframes to exchange:

- Jobs
- Sysout
- Commands / messages (depending on config)
- Files

### Why it is high risk
Trust between nodes can allow **job submission into a remote system**. Misconfigured NJE is a classic lateral-movement path between LPARs/sites.

### Controls
- Strong node authentication (not default open trust)
- TLS where supported
- Tight partner allowlists
- Command transmission disabled or tightly constrained
- Monitor unexpected node connections

### Testing
Community tools exist (e.g. NJE-oriented libraries/scripts). Only use in scope with extreme caution — you can impact remote production job flow.

---

## 7. CICS

**Customer Information Control System** — dominant OLTP middleware.

### Attack / test surface
- Transactions (4-char IDs)
- Default/admin transactions if exposed
- Business apps with authZ flaws
- Breakout from app to CICS admin functions
- Web/CICS gateway exposures
- Program link / file access / transient data queues

### High-level issue classes
See [[07-CICS-IMS-DB2-Application-Testing]].

### Controls
- Transaction security via ESM
- Suppress dangerous default transactions in PROD
- Separate CICS regions by trust level
- No CECI/CEMT for general users
- Parameter integrity, program pathing, storage protection settings reviewed by sysprogs

---

## 8. IMS

IMS provides:

- **IMS TM** (transactions)
- **IMS DB** (hierarchical database)

Security is a combination of IMS controls + ESM. Assessment requires understanding of which transactions, PSBs, and regions are exposed and how authentication is enforced (including via OTMA, connect, MQ bridges).

---

## 9. Db2 for z/OS

### Surface
- Distributed data facility (DDF) ports
- JDBC/ODBC from mid-tier apps
- Internal authorization (Db2 privileges) **and** SAF resources
- Sensitive table data, GRANTs, secondary auth IDs

### Issue classes
- Over-granted Db2 privileges (`SYSADM`-like sprawl)
- Weak app bind-in credentials
- SQL injection in front-end apps that hit Db2
- Insufficient subsystem security exit / ESM integration
- Sensitive data in test subsystems copied from prod

---

## 10. IBM MQ

- Queue managers, channels, listeners
- Channel auth (CHLAUTH), TLS, MCA users
- Poisonous trust: channel accepts connection and runs as powerful MCAUSER

**Classic finding:** channels with weak/blank authentication and highly privileged MCAUSER.

---

## 11. USS network services

| Service | Notes |
|---------|-------|
| SSH | Preferred interactive USS access |
| Telnet | Legacy; avoid |
| HTTP Server / WebSphere | Web apps, admin consoles |
| z/OSMF | Management facility — high value if exposed |
| Containers / Open Shift on Z | Modern attack surface if deployed |

Web apps can yield RCE into USS; from USS, attackers hunt RACF misconfigs and credentials.

---

## 12. Crypto & key services

Not always “open ports,” but attack-relevant:

- Who can use **CSFSERV** resources
- Access to key datasets
- Misissued certificates
- Clear key material in datasets/USS files

---

## 13. Monitoring / ISV / ops tooling

Often overlooked:

- Performance monitors
- Scheduling UIs
- Backup/replication interfaces
- Vendor agents with APF requirements
- RMF portals, NetView-related services (legacy vulns have existed)

APF-authorized ISV tools expand the trusted computing base — review their library protections.

---

## 14. Identity bridges (hybrid attack surface)

| Bridge | Risk |
|--------|------|
| LDAP / AD sync | Password reuse, directory compromise → mainframe |
| Kerberos | Ticket theft / misconfig |
| MFA integrations | Bypass paths if not uniformly enforced |
| Enterprise SSO portals | Phishing for mainframe-capable creds |
| Mid-tier service accounts | One app ID with broad dataset rights |

Many real-world paths start on **Windows/Linux** and end on the mainframe via reused credentials or over-trusted service IDs.

---

## 15. Physical / operator surface (usually out of scope but real)

- HMC (Hardware Management Console)
- Operator consoles
- Tape / backup handling
- Physical data center access

HMC compromise is catastrophic. Typically separate red-team / infra scope.

---

## Prioritized attack surface for a first pentest

1. **Identity exposure** (TN3270/FTP/SSH authN)
2. **Clear-text protocols**
3. **FTP → JES**
4. **CICS transaction security**
5. **Dataset + APF permissions** (post-auth)
6. **SURROGAT / BPX / OPERCMDS**
7. **MQ channels / web apps**
8. **NJE trust**
9. **Lateral to other LPARs / distributed systems**

---

**Next:** [[05-Pentest-Methodology]]
