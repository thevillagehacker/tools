# 01 — Introduction & Architecture

## Why mainframes still matter

Mainframes (especially **IBM Z**) still run a large share of:

- Core banking and card authorizations
- Airline / logistics reservation systems
- Insurance and government transaction systems
- High-volume batch (nightly settlement, payroll, billing)

They are designed for **extreme reliability, throughput, and auditability**. That does **not** mean they are unhackable. Most compromises come from:

- Weak identity / password hygiene
- Over-entitlement (group sprawl, SPECIAL / OPERATIONS abuse)
- Misconfigured middleware (CICS, FTP/JES, NJE)
- Hybrid integration (web, MQ, LDAP, distributed apps fronting the mainframe)

Modern ransomware and privilege-escalation discussions increasingly include mainframes because they hold high-value data and trust relationships to the rest of the enterprise.

---

## What “mainframe” means in practice

| Term | Meaning |
|------|---------|
| **Mainframe (hardware)** | Large multi-tenant enterprise system (IBM Z, LinuxONE, etc.) |
| **LPAR** | Logical partition — isolated OS instance on one machine |
| **Sysplex / Parallel Sysplex** | Cluster of z/OS systems sharing workload and data |
| **CECs / CPC** | Central Electronic Complex / Central Processor Complex (the box) |
| **DASD** | Disk storage volumes |
| **Dataset** | z/OS “file” (not POSIX path by default) |
| **PDS/PDSE** | Partitioned dataset — roughly “folder of members” |

---

## IBM Z hardware family (models)

IBM Z (formerly System z / z Systems) is the dominant enterprise mainframe line. Generations relevant for learning:

| Generation | Approx. era | Security / tech notes (high level) |
|------------|-------------|-------------------------------------|
| **zEC12 / zBC12** | ~2012 | Mature crypto adapters; older but still in some estates |
| **z13 / z13s** | ~2015 | Strong crypto + virtualization scale |
| **z14 / z14 ZR1** | ~2017 | **Pervasive Encryption** era begins in earnest |
| **z15 / z15 T02** | ~2019 | Data privacy passports, hybrid cloud focus |
| **z16** (Telum) | ~2022 | On-chip AI, quantum-safe crypto features, Crypto Express 8S |
| **z17** | ~2025+ | Latest IBM Z line (AI + resiliency continued) |

**Also related:**

- **IBM LinuxONE** (Emperor / Rockhopper lines) — same hardware DNA, Linux-first packaging
- **Specialty engines:** zIIP, IFL (Linux), ICF (coupling), crypto coprocessors

### Processor / crypto hardware you will hear about

| Component | Role |
|-----------|------|
| **CPACF** | CPU-based crypto acceleration (AES, SHA, etc.) |
| **Crypto Express** (CEX) | Hardware Security Module-class crypto cards |
| **ICSF** | Integrated Cryptographic Service Facility (software interface to crypto) |
| **CKDS / PKDS / TKDS** | Key data sets for crypto keys |

**Pentest angle:** Hardware generation affects *encryption capabilities* and *compliance stories*, not whether RACF misconfigs exist. Misconfigurations are OS/ESM/process issues on every generation.

---

## Virtualization stack (critical concept)

IBM Z is virtualized by default:

```
┌─────────────────────────────────────────┐
│              PR/SM (firmware)           │  ← creates LPARs
├──────────┬──────────┬───────────────────┤
│  LPAR 1  │  LPAR 2  │  LPAR 3 ...       │
│  z/OS    │  z/VM    │  Linux / z/OS     │
│          │   ├─ guest Linux             │
│          │   ├─ guest z/OS (less common)│
│          │   └─ many VMs                │
└──────────┴──────────┴───────────────────┘
```

| Layer | Name | Notes |
|-------|------|-------|
| Firmware hypervisor | **PR/SM** | Creates LPARs; strong isolation baseline |
| Type-1 guest hypervisor | **z/VM** | Massive guest density (esp. Linux) |
| Alternative Linux virt | **KVM on Z** | Runs in an LPAR on supported hardware |

**Security implications:**

- Compromise of one LPAR does **not** automatically own another (by design).
- Shared infrastructure (NJE, shared DASD, coupling facility, common credentials, network paths) creates **lateral movement**.
- z/VM security is its own domain (directory, privilege classes, guest isolation).

---

## Core z/OS functional modules (what you attack/test)

From a security-assessment view, z/OS is often described as:

1. **System services** — BCP (kernel-like), JES, DFSMS (storage), TSO
2. **Admin / management services** — operators, SDSF, consoles, automation
3. **UNIX System Services (USS / OMVS)** — POSIX layer (FTP, SSH, web, scripts)

Built on top:

| Subsystem | Role |
|-----------|------|
| **JES2 / JES3** | Batch job entry, queue, output |
| **VTAM / SNA + TCPIP** | Network access to apps |
| **CICS** | Online transaction processing |
| **IMS** | Transaction + hierarchical DB |
| **Db2** | Relational database |
| **MQ** | Messaging |
| **WebSphere / z/OS Connect / HTTP Server** | Web / API front ends |
| **RACF (or ACF2/TSS)** | Security database + decision engine |

---

## Key concepts for newcomers (cheat sheet)

| Concept | Think of it as… |
|---------|------------------|
| **TSO** | Interactive CLI session for users |
| **ISPF** | Menu / panel UI on top of TSO |
| **JCL** | Batch job language (submit work) |
| **REXX / CLIST** | Scripting languages |
| **Dataset** | File |
| **Volume / DASD** | Disk |
| **APF** | “Trusted / privileged program” list (similar spirit to setuid-root libraries) |
| **SAF** | Kernel security API |
| **ESM** | RACF / ACF2 / Top Secret |
| **SPECIAL** | Near-god privileges in RACF |
| **Started task** | System service identity (like a service account) |
| **TN3270** | Terminal protocol (green screen) |
| **VTAM APPLID** | Named application entry point |

---

## Encoding & character sets (practical footgun)

- Traditional z/OS datasets and many green-screen apps use **EBCDIC**, not ASCII.
- USS can mix ASCII/EBCDIC depending on file tags and tools.
- Shells and reverse shells often need **EBCDIC-aware** tooling (or conversion with `iconv` / dedicated clients).

---

## Multi-system topology you may see

```
     [Internet / Partner]
              |
         [Firewall / WAF]
              |
     [Web / API / MQ gateway]
              |
   ┌──────────┴──────────┐
   │   z/OS Sysplex      │
   │  PROD LPAR ── CF    │
   │  TEST LPAR          │
   │  DEV LPAR           │
   └──────────┬──────────┘
              |
     NJE / shared storage / LDAP / AD bridge
              |
     Other CECs / remote sites
```

**Assessment tip:** Scope must define *which LPARs*, *which sysplex*, *which subsystems*, and *whether NJE/shared DASD* is in scope.

---

## Why classic network pentesting is incomplete

Scanning ports finds the door. Mainframe risk usually lives in:

1. **Identity** — weak passwords, shared IDs, no MFA
2. **Authorization models** — UACC, WARN mode, broad generics
3. **Trusted code paths** — APF, program control, USS extattr
4. **Middleware breakout** — CICS CECI/CEMT, IMS, poorly constrained transactions
5. **Trust between systems** — NJE, surrogate submit, batch schedulers
6. **Hybrid bridges** — SSO, LDAP, Kerberos, WebSphere, distributed middleware

---

## Learning goals after this chapter

You should be able to answer:

- [ ] What is an LPAR vs a full physical mainframe?
- [ ] Why PR/SM isolation is strong but not the whole story for lateral movement?
- [ ] What SAF + ESM means for every resource access check?
- [ ] Why “mainframe security” is mostly configuration + identity, not memory-corruption 0-days?

**Next:** [[02-Operating-Systems]]
