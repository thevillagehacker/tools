# Mainframe Penetration Testing — Learning Notes

> **Purpose:** Structured notes for learning authorized mainframe security assessment (IBM Z / z/OS-focused, with coverage of other platforms).  
> **Scope:** Architecture, OSes, security controls, attack surface, methodology, tools, and checklists.  
> **Rule:** Use only on systems you own or are explicitly authorized to test. Mainframes often run core banking, payments, and government workloads — treat production carefully and prefer TEST/QA LPARs.

---

## How to use these notes

| Order | Note | Focus |
|------:|------|--------|
| 1 | [[01-Introduction-and-Architecture]] | What a mainframe is, hardware generations, LPAR/PR/SM |
| 2 | [[02-Operating-Systems]] | z/OS, z/VM, z/VSE, z/TPF, Linux on Z, IBM i |
| 3 | [[03-Security-Architecture-and-Controls]] | SAF, RACF/ACF2/TSS, encryption, audit, PAM |
| 4 | [[04-Attack-Surface-and-Services]] | Ports, VTAM, TN3270, CICS, IMS, DB2, JES, NJE, MQ |
| 5 | [[05-Pentest-Methodology]] | End-to-end assessment phases |
| 6 | [[06-Privilege-Escalation-and-Misconfigs]] | APF, SURROGAT, BPX, WARNING, common privesc |
| 7 | [[07-CICS-IMS-DB2-Application-Testing]] | Middleware / application layer |
| 8 | [[08-Tools-and-Lab-Setup]] | Tools, scripts, lab options |
| 9 | [[09-Other-Platforms-IBM-i-and-Non-IBM]] | IBM i (AS/400), Unisys, LinuxONE, others |
| 10 | [[10-Checklist-and-Reporting]] | Field checklist + reporting map |
| 11 | [[11-Resources-and-References]] | Curated books, talks, STIGs, blogs |
| 12 | [[12-Command-Cheatsheet]] | **Field commands** with why you run each (recon → privesc → exfil) |
| 13 | [[13-Console-CLI-Application-Security-Testing]] | **Console/CLI business apps** A→Z testing + Go harness |
| 14 | [[14-mf-cli-appsec-Usage-Guide]] | **How to use** `mf-cli-appsec.exe` v0.3 (global TN3270): options, flows, site config |

---

## Reality check (important)

**“Every device, every model, every OS”** is a large landscape. These notes cover:

- **Primary market (deep):** IBM Z hardware + **z/OS** + ESM security (RACF / ACF2 / Top Secret)
- **Important siblings:** z/VM, Linux on IBM Z / LinuxONE, z/VSE, z/TPF
- **Adjacent platform:** **IBM i** (Power / former AS/400) — often lumped into “mainframe” engagements
- **Other mainframe families (overview):** Unisys ClearPath, Fujitsu BS2000, Bull GCOS, etc.

Most public pentest research, tools, and commercial services focus on **IBM z/OS**. That is where skills transfer best for employment and real assessments.

---

## Engagement principles

1. **Prefer non-prod:** Ask for TEST/QA LPARs that mirror production security.
2. **OPSEC & safety:** Avoid mass account lockouts, destructive JCL, and uncoordinated APF/SETPROG changes.
3. **Do not invent CVEs or flags** — verify against IBM docs / engagement evidence.
4. **Document controls, not just exploits** — good mainframe assessments are often configuration-driven.
5. **SPECIAL ≈ root** on z/OS RACF; treat privileged findings as critical.

---

## Quick mental model

```
Network → TN3270 / FTP / SSH / HTTP / MQ / NJE
              ↓
         VTAM / TCPIP
              ↓
   CICS | IMS | TSO/ISPF | USS | JES | DB2 | MQ
              ↓
              SAF
              ↓
     RACF | ACF2 | Top Secret
              ↓
     Datasets | Resources | Users | Groups
```

---

## Status

| Item | Status |
|------|--------|
| Created | 2026-07-17 |
| Primary focus | IBM Z / z/OS security assessment |
| Lab lab ready | See `08-Tools-and-Lab-Setup.md` |

Start here → **[[01-Introduction-and-Architecture]]**
