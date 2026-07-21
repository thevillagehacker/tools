# 02 — Operating Systems on Mainframes

Mainframe “OS” is not one product. Multiple OSes can run on the same IBM Z box in different LPARs (or as z/VM guests).

---

## Platform map

| OS / Environment | Typical role | Security focus for pentests |
|------------------|--------------|-----------------------------|
| **z/OS** | Primary enterprise transaction + batch OS | RACF/ACF2/TSS, datasets, APF, CICS/IMS/Db2 |
| **z/VM** | Hypervisor + interactive CMS heritage | Directory privileges, guest isolation, networking |
| **Linux on IBM Z** | Linux workloads on IFL engines / LPARs | Same as Linux + platform integration, crypto, shared nets |
| **IBM LinuxONE** | Linux-optimized IBM Z packaging | Linux + Z crypto / isolation story |
| **z/VSE** | Smaller IBM mainframe OS (legacy SMB / regional) | Different admin model; less public pentest material |
| **z/TPF** | Extreme high-volume transaction OS (airlines, etc.) | Niche; specialized access models |
| **IBM i** (Power) | Not z/Architecture; often assessed as “midrange/mainframe-like” | Object-level security, user profiles, network services |
| **Non-IBM mainframes** | Unisys, Fujitsu BS2000, Bull GCOS, etc. | Separate ecosystems (overview in note 09) |

---

## 1. z/OS (primary target for most pentests)

### What it is
IBM’s flagship mainframe OS. Descended from MVS. Runs:

- Online systems (CICS, IMS TM)
- Batch (JES2/JES3)
- Databases (Db2, IMS DB, VSAM)
- USS (POSIX / UNIX System Services)
- Modern Java, Node (via z/OS Container Extensions in some setups), WebSphere, z/OS Connect

### Releases you may see
z/OS 2.x and 3.x lines in production. Security features evolve, but **classic misconfig classes remain stable**.

### Security-relevant building blocks
| Component | Notes |
|-----------|-------|
| **SAF** | Authorization call interface |
| **RACF / ACF2 / TSS** | External Security Manager |
| **SMF** | Audit / accounting records |
| **USS** | `/u`, `/etc`, web, FTP, SSH, Java |
| **Program Control / APF** | Integrity of privileged code |
| **ICSF** | Crypto services |
| **AT-TLS** | TLS without app rewrite |

### Interfaces users actually touch
| Interface | Description |
|-----------|-------------|
| **TN3270 → VTAM → TSO/ISPF** | Classic interactive admin/user path |
| **SSH / Telnet to USS** | Unix shell |
| **FTP / SFTP / FTPS** | File transfer; FTP can also submit JCL to JES |
| **HTTP / WebSphere / z/OSMF** | Web admin & apps |
| **MQ / Db2 clients / CICS gateways** | Application integration |

### When z/OS is “owned”
Practically: ability to act as a highly privileged identity (e.g. RACF **SPECIAL**), write APF libraries, control security DB, or freely read/alter critical business datasets / payment flows.

---

## 2. z/VM

### What it is
Type-1 hypervisor running **inside** an LPAR created by PR/SM. Famous for huge Linux guest density. Also hosts CMS and other guests historically.

### Security concepts
| Concept | Why it matters |
|---------|----------------|
| **User directory** | Defines guests, privileges, disks, networking |
| **Privilege classes** (A–G etc.) | Command authority for operators / admins |
| **Guest isolation** | Primary security promise |
| **Shared minidisks / links** | Lateral data access if mis-shared |
| **VSWITCH / networking** | Guest-to-guest and external traffic |

### Pentest angles
- Weak or default directory passwords (lab/legacy)
- Over-privileged service virtual machines
- Shared disks with sensitive data
- Escape / misconfig between guests and management interfaces
- Management tooling exposure (web, automation)

### Relationship to z/OS pentests
Often you will **not** get z/VM access during a pure z/OS app test. If scope includes infrastructure, z/VM is a high-value pivot plane.

---

## 3. Linux on IBM Z / LinuxONE

### Distributions commonly seen
- **RHEL** for IBM Z
- **SLES** for IBM Z
- **Ubuntu** for IBM Z

### What is the same as distributed Linux
- Users, SSH, packages, containers (Podman/K8s patterns), kernel vulns, web stacks

### What is different / extra
| Topic | Notes |
|-------|-------|
| Architecture | **s390x** binaries, not x86_64 |
| Crypto | Can use CPACF / Crypto Express via kernel & libraries |
| Networking | OSA, RoCE, HiperSockets (memory network between LPARs) |
| Storage | FCP, ECKD DASD via Linux device model |
| Colocation | Same CEC as z/OS → shared physical trust boundary discussions |

### Pentest approach
Standard Linux methodology **plus** platform-specific networking and credential reuse with z/OS / enterprise IAM.

---

## 4. z/VSE

- Aimed at smaller mainframe shops.
- Different subsystem landscape than full z/OS estates.
- Less open public pentest tooling than z/OS.
- Still uses mainframe networking concepts and careful change control.

**Learning priority:** know it exists; deep-dive only if your target uses it.

---

## 5. z/TPF (Transaction Processing Facility)

- Built for extreme transaction rates (classic: airlines, card processors).
- Highly specialized OS and application model.
- Public “hacking guides” are scarce; assessments are specialist engagements.

**Learning priority:** awareness only unless you work in that niche.

---

## 6. IBM i (formerly AS/400 / iSeries / System i)

**Not** IBM Z. Runs on **IBM Power** hardware. Still appears in “mainframe/midrange” security programs.

### Why include it
- Often coexists in the same enterprise as z/OS
- Similar “legacy critical system” risk profile
- Different security model (object-based)

### Security model highlights
| Concept | Notes |
|---------|-------|
| **User profiles** | Identity + special authorities |
| **Object authority** | *ALL, *CHANGE, *USE, *EXCLUDE, etc. |
| **Library lists** | Path-like resolution for programs/files |
| **IFS** | Integrated File System (POSIX-like paths) |
| **Network servers** | FTP, ODBC, remote command, NetServer, SSH (modern) |
| **SECOFR** | Security officer — super-admin role |

### Common assessment themes
- Default / weak profiles
- Excessive special authorities (`*ALLOBJ`, `*SECADM`, `*JOBCTL`, …)
- Public authority too open on libraries/objects
- Clear-text protocols
- Command execution via network services
- Password hash extraction & offline cracking (historical research exists)

Details and tools: see [[09-Other-Platforms-IBM-i-and-Non-IBM]].

---

## 7. Non-IBM mainframe OS families (awareness)

| Family | OS examples | Notes |
|--------|-------------|-------|
| **Unisys ClearPath** | OS 2200 (Dorado), MCP (Libra) | Separate security admin models |
| **Fujitsu** | BS2000/OSD, older GS series | Regional (esp. Europe/Japan legacy) |
| **Bull / Atos** | GCOS | Niche remaining estates |

Public pentest material is sparse. Treat as **vendor + site-specific**. IBM Z skills do not directly transfer command-for-command.

---

## OS identification during recon

| Clue | Likely platform |
|------|-----------------|
| TN3270 + TSO/ISPF banners, RACF messages | z/OS |
| Ports 23/992 TN3270, 21 FTP with z/OS banners, 175 NJE | z/OS |
| SSH only, s390x banners, Linux kernel | Linux on Z |
| 5250 protocol (not 3270), IBM i services | IBM i |
| Explicit vendor banners (ClearPath, BS2000) | Non-IBM |

Nmap version detection + banner grabbing + protocol fingerprinting usually separates these quickly.

---

## Multi-OS on one machine (realistic picture)

A single IBM Z CEC might run:

- LPAR A: z/OS PROD sysplex member
- LPAR B: z/OS TEST
- LPAR C: z/VM hosting 200 Linux guests
- LPAR D: LinuxONE-style RHEL for middleware
- Coupling facility LPARs for sysplex

**Your scope document must name the OS instances**, not just “the mainframe.”

---

## Security control baseline differs by OS

| Control domain | z/OS | Linux on Z | IBM i |
|----------------|------|------------|-------|
| Identity store | RACF/ACF2/TSS | /etc, LDAP, IdM | User profiles / LDAP |
| AuthZ model | Dataset + resource classes | POSIX + MAC optional | Object authorities |
| Privileged role | SPECIAL / OPERATIONS | root / capabilities | SECOFR / *ALLOBJ |
| Audit spine | SMF | auditd / SIEM agents | Journaling / audit journals |
| Crypto HW | ICSF + CEX + CPACF | CPACF/CEX via Linux | Power crypto features |

---

## Learning priority (recommended)

1. **z/OS + RACF** (80% of public methodology)
2. **USS / Linux-like skills on z/OS**
3. **CICS + JES/FTP**
4. **Linux on Z** (if hybrid estate)
5. **IBM i** (if in scope)
6. Everything else as needed

**Next:** [[03-Security-Architecture-and-Controls]]
