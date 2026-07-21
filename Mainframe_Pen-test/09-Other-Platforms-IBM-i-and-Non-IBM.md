# 09 — Other Platforms: IBM i, LinuxONE, Non-IBM Mainframes

IBM z/OS is the center of gravity for public mainframe pentest material. Real enterprises also run other “big iron” platforms.

---

## 1. IBM i (AS/400 / iSeries / System i)

### Positioning
- Runs on **IBM Power**, not IBM Z.
- Object-based OS with deep integrated DB (Db2 for i).
- Still critical in manufacturing, distribution, mid-market ERP, and some banks.

### Security model (essentials)

| Concept | Notes |
|---------|-------|
| **User profile** | Identity + attributes + special authorities |
| **Group profiles** | Grouping & authority inheritance patterns |
| **Object authority** | *USE, *CHANGE, *ALL, *EXCLUDE, authorization lists |
| **Special authorities** | e.g. *ALLOBJ, *SECADM, *JOBCTL, *SPLCTL, *SERVICE, *IOSYSCFG |
| **Library list** | Resolution order for unqualified objects |
| **IFS** | `/` style file system alongside libraries |
| **SECOFR** | Powerful security officer profile |

### Common network services
- 5250 (twinax heritage; now TN5250 over TCP)
- FTP / SFTP
- ODBC / JDBC
- NetServer (SMB-like)
- Remote command
- SSH (on modern releases)
- Host servers for IBM i Access

### Frequent assessment findings
1. Profiles with *ALLOBJ that are not truly needed  
2. Default or well-known passwords on old profiles  
3. Public authority too open on libraries/IFS  
4. Clear-text protocols still enabled  
5. Command-line access for users who only need app menus  
6. Weak exit program / network attribute hardening  
7. Password hashing / offline audit issues (research tooling exists historically)  
8. Over-powered service accounts used by ETL and RPA  

### Tooling / resources
- **hack400tool** and related IBM i security toolkits (community)
- John the Ripper format support historically discussed for IBM i hashes
- 5250 emulators (tn5250, commercial Access clients)
- Books: *Hacking iSeries* (Shalom Carmel), IBM i security guides by Woodbury/Botz era literature
- Talks: Black Hat / community “Hack the Legacy” style presentations

### Methodology sketch
1. Service discovery (5250 vs 3270 distinction!)  
2. Auth testing (careful lockouts)  
3. Profile & special authority review  
4. Object authority sampling on sensitive libraries  
5. Network attribute & exit program review  
6. IFS sensitive file hunt  
7. Lateral via linked servers / ODBC / shared creds  

### Control baseline ideas
- Least special authorities
- Disable unused host servers
- Force encrypted connections
- Regular profile recertification
- Separation of SECOFR duties
- Audit journal monitoring to SIEM
- Strong password rules / MFA options where available

---

## 2. Linux on IBM Z & LinuxONE

### What you are testing
Linux (**s390x**) with enterprise packaging and optional access to Z crypto / virtualization features.

### Hardware brands
- IBM Z LPARs with IFLs
- **LinuxONE** (Emperor / Rockhopper generations; LinuxONE 4/5 etc.)

### Approach
Standard Linux + container + K8s methodology, plus:

| Extra focus | Why |
|-------------|-----|
| HiperSockets / shared nets | Proximity to z/OS LPARs |
| Crypto offload | Key access & accelerator misconfig |
| s390x exploit specifics | Different binaries/shellcode world |
| Colocation risk | Same CEC as payment systems |

### Controls
- Same as hardened RHEL/SLES/Ubuntu CIS baselines
- Secure boot / image signing where used
- Strict separation from z/OS management networks unless required
- SSH hardening, MFA, no shared root

---

## 3. z/VM as a target platform

If scope includes hypervisor administration:

| Review area | Notes |
|-------------|-------|
| Directory maintenance | Who can change guest definitions |
| Privilege classes | Operator superpowers |
| Network config | VSWITCH isolation |
| Disk sharing | Minidisk links |
| Management APIs / web | AuthN strength |
| Guest escape claims | Treat carefully; focus on config isolation |

---

## 4. z/VSE and z/TPF

| OS | Practical advice |
|----|------------------|
| **z/VSE** | Smaller estates; rely on vendor docs + site runbooks; fewer public tools |
| **z/TPF** | Highly specialized; assessments are niche professional services |

Do not assume RACF commands apply. Confirm security product and interfaces per site.

---

## 5. Non-IBM mainframe families

These remain in some industries/regions. Skills transfer is **conceptual** (identity, least privilege, batch trust, clear-text protocols), not command-level.

### Unisys ClearPath
| Line | OS heritage |
|------|-------------|
| **Dorado** | OS 2200 (UNIVAC lineage) |
| **Libra** | MCP (Burroughs lineage) |

Security admin, user authentication, and program controls are product-specific. Expect heavy reliance on vendor documentation and customer SMEs.

### Fujitsu BS2000 / OSD
- European legacy presence historically strong
- Distinct OS security mechanisms

### Bull / Atos GCOS
- Remaining GCOS estates in some markets
- Specialist knowledge required

### Assessment approach for non-IBM
1. Identify exact product + version  
2. Collect vendor security guides  
3. Map services (terminal protocols, FTP-like, DB, messaging)  
4. Review identity store & privilege model with admins  
5. Test exposed network services carefully  
6. Prioritize trust relationships and batch job authority  

---

## 6. “Mainframe-like” enterprise servers (boundary of scope)

Sometimes lumped into programs:

- Large **IBM Power** AIX estates
- NonStop / Tandem-style systems (payments)
- Vendor appliances co-located in mainframe networks

Handle under separate methodology notes; do not force z/OS checklists onto them.

---

## 7. Platform identification cheat sheet

| Observation | Platform guess |
|-------------|----------------|
| TN3270 + TSO/RACF messages | z/OS |
| TN5250 + IBM i signon | IBM i |
| SSH + `s390x` / Linux banners on big-iron IP space | Linux on Z |
| Vendor ClearPath banners / docs | Unisys |
| Customer says “AS/400” | IBM i (name stickiness) |
| Customer says “the mainframe” | **Ask which OS** |

---

## 8. Learning priority if time-limited

1. z/OS + RACF  
2. CICS basics  
3. Linux on Z (if hybrid)  
4. IBM i fundamentals  
5. Everything else on-demand  

---

**Next:** [[10-Checklist-and-Reporting]]
