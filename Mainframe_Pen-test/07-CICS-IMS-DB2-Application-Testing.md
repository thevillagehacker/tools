# 07 — CICS, IMS, Db2 & Application-Layer Testing

Middleware is where business risk lives. Many mainframes are “secure at RACF” but weak in **transaction security** and **app authorization**.

---

## A. CICS testing

### What CICS is
Online transaction monitor. Clients (3270, web, middleware) invoke **transactions** that run **programs** accessing **files/DB/MQ**.

### Core objects

| Object | Description |
|--------|-------------|
| **Region** | A CICS address space instance (PROD/TEST/etc.) |
| **Transaction** | 4-character code users invoke |
| **Program** | Load module executed |
| **File / TDQ / TSQ** | Data resources inside CICS |
| **User** | Authenticated identity (or default user pitfalls) |

### Entry paths
- TN3270 → VTAM APPLID → CICS
- Web / CICS Transaction Gateway / z/OS Connect
- MQ bridge
- EXCI / other region links

---

### High-value test themes (7 common patterns)

Public industry write-ups (e.g. NetSPI CICS series) cluster around themes like:

1. **Default / dangerous transactions exposed**
   - Admin or diagnostic transactions available to ordinary users
   - Examples often discussed in literature: CEMT, CECI, CEDF, CESN/CESF related flows, etc. (availability depends on region config)

2. **Weak or missing transaction security**
   - Transactions not covered by ESM
   - Same transaction allowed across trust tiers

3. **Authentication gaps**
   - Using default CICS user for unauthenticated work
   - Session not bound tightly to RACF user

4. **Business logic / IDOR-like issues**
   - Transaction accepts account numbers without ownership checks
   - Classic web-IDOR ideas apply to green-screen fields too

5. **Field-level / 3270 presentation abuses**
   - Hidden fields containing sensitive values
   - Client-side field protection assumptions

6. **File / resource access via CICS**
   - Read/write VSAM or queues beyond role
   - Data leakage via TSQ/TDQ

7. **Breakout to system functions**
   - From app transaction to command-level tools
   - JCL submission / program upload paths when CECI-like capability exists

### Tooling references (community)
- **CICSpwn** — research tooling around CICS interaction/abuse paths
- **BIRP** (Sensepost) — 3270 application testing helper
- Nmap `cics-enum`, `cics-user-enum`, `cics-user-brute` (need care + often credentials/APPLID)
- Modified 3270 emulators for field visualization

### Controls checklist (CICS)

- [ ] All transactions defined to ESM with least privilege
- [ ] Admin transactions restricted to admin groups / locked regions
- [ ] Separate regions for high-trust vs low-trust apps
- [ ] No shared default user with broad rights
- [ ] Parameter integrity / storage protection reviewed by sysprogs
- [ ] Logging of sensitive transactions to SMF/SIEM
- [ ] Web/gateway authN aligned with RACF policies
- [ ] Secrets not in TSQs or clear-text maps

---

## B. IMS testing

### Components
| Component | Role |
|-----------|------|
| **IMS DB** | Hierarchical database |
| **IMS TM** | Transaction manager |
| **Dependent regions** | MPP, BMP, IFP, etc. |
| **Connect / OTMA / MQ** | External access paths |

### Test focus
- Transaction authorization (who can run which tran codes)
- PSB/PCB sensitivity (data sensitivity of databases accessed)
- External connect authentication
- Mid-tier service accounts with broad IMS authority
- Sensitive segments exposed to test users

### Controls
- ESM integration enabled (not only local IMS security)
- Least privilege PSBs
- Strong auth on OTMA/connect paths
- Prod/test data separation

IMS assessments often need a specialist or deep app owner support — document architecture first.

---

## C. Db2 for z/OS testing

### Privilege model (two layers)
1. **Db2 privileges** — GRANT/REVOKE within Db2 (SYSADM, DBADM, table privs, packages, plans)
2. **SAF/ESM resources** — subsystem connection, some command protections

### Attack / test paths
| Path | Notes |
|------|-------|
| Overprivileged app IDs | App connects as near-SYSADM |
| Secondary auth IDs | Unexpected group privileges |
| SQL injection | In web/service front ends |
| Weak bind-in credentials | Config files on mid-tier |
| Data copies | PROD data in DEV with weak controls |
| Inadequate column controls | PII readable by too many roles |

### Control checks
- [ ] No human interactive SYSADM sprawl
- [ ] App IDs least privilege on tables/packages
- [ ] SSL/TLS for DDF connections
- [ ] Audit privileged Db2 actions
- [ ] Masking/tokenization for non-prod
- [ ] Separation of security admin vs data admin where required

### Practical assessor approach
1. Identify connection ports / location names  
2. Determine auth mechanism (user/pass, cert, passticket, mid-tier)  
3. Enumerate privileges for the test identity  
4. Attempt read of canary sensitive tables only  
5. Review GRANT graphs with DBAs if config audit mode  

---

## D. MQ application security (brief)

Channels + auth + MCAUSER dominate risk.

Test:

- Anonymous / weak channel auth
- Admin commands via insecure channels
- Message injection into sensitive queues
- Clear-text channels

Controls: CHLAUTH, TLS, least privilege MCAUSER, channel IP allowlists, separate QMGRS by trust.

---

## E. Web / API front ends to mainframe

Modern estates expose:

- IBM HTTP Server apps
- WebSphere applications
- z/OS Connect APIs
- Partner APIs → CICS/IMS/Db2

### Test like a normal app PT, then continue on-box
- OWASP ASVS / WSTG style testing
- AuthN/Z flaws
- Injection
- File upload → USS RCE
- SSRF to internal mainframe services (rare but think internal IPs)

Historical examples of mainframe web-stack vulnerabilities exist in public CVE/research; always version-check before claiming exploitability.

---

## F. 3270 application testing methodology

1. Map all transactions / screens  
2. Identify authn boundaries  
3. Test horizontal access (user A sees user B data)  
4. Test vertical access (user → admin functions)  
5. Tamper with hidden fields / unprotected fields using research tooling  
6. Capture business impact (fund transfer, PII, approvals)  
7. Trace whether back-end ESM checks exist or only UI hides functions  

---

## G. Mapping app findings to system risk

| App finding | System impact |
|-------------|---------------|
| CICS admin tran for all users | Potential region takeover / data access |
| Db2 app ID with SELECT on all PII | Compliance catastrophe without SPECIAL |
| MQ channel as admin | Message fabric compromise |
| Web RCE on USS | Foothold to hunt RACF misconfigs |

Do not under-rate app findings just because they are not “SPECIAL obtained.”

---

## H. Console / CLI application deep-dive

For a full A→Z methodology (authZ matrices, IDOR on green-screen fields, business logic, automation with a Go + s3270 harness), see:

**[[13-Console-CLI-Application-Security-Testing]]** and toolkit `tools/mf-cli-appsec/`.

---

## H. Evidence examples (safe)

- Screenshot of restricted transaction access granted incorrectly  
- Query result of non-sensitive canary row  
- ESM profile showing UACC/perms on transaction resource  
- Channel definition redacted showing MCAUSER weakness  

---

**Next:** [[08-Tools-and-Lab-Setup]]
