# 08 — Tools & Lab Setup

Mainframe pentesting is **tool-assisted**, not fully automated. You still need to read ESM output and understand JCL/TSO.

---

## A. Essential client tools

| Tool | Use |
|------|-----|
| **x3270 / c3270 / wc3270** | TN3270 terminal |
| **Nmap** (+ mainframe NSE scripts) | Port/service/app enum |
| **Burp Suite** | Webized 3270 / WebSphere / APIs |
| **FTP/SFTP clients** | File & JES workflows |
| **OpenSSH client** | USS access |
| **Python 3** | Glue scripts, NJE libs, automation |
| **Git** | Track your notes & scripts |

### Nmap script families (community / nmap bundled)

Examples often used in public guides:

| Script | Purpose |
|--------|---------|
| `tn3270-screen` | Capture screens |
| `vtam-enum` | VTAM application enum |
| `lu-enum` | LU enumeration |
| `tso-enum` / `tso-brute` | TSO user/cred testing |
| `cics-enum` / `cics-user-*` | CICS enum (careful) |
| `nje-node-brute` / `nje-pass-brute` | NJE related |

Always rate-limit; account lockouts are real.

---

## B. Community security tools (research)

These appear frequently in Awesome-Mainframe-Hacking style lists. Review licenses and use only when authorized.

| Project / type | Purpose |
|----------------|---------|
| **mainframed** tools (TShOcker, MainTP, Enumeration, NC110-OMVS, etc.) | Foothold, enum, USS helpers |
| **ayoul3** REXX / Privesc / CICSpwn | Privesc & CICS research |
| **sensepost/birp** | 3270 app testing |
| **zedsec390/NJElib** | NJE protocol research |
| **RACF DB parsers** | Offline analysis of RACF DB extracts |
| **Metasploit mainframe modules** | FTP/JCL, payloads (lab use) |
| **patator / hydra** | Careful credential testing |
| **TPX-Brute / TSO-Brute** | Panel-specific testing |

### Metasploit (examples referenced publicly)
- `exploit/mainframe/ftp/ftp_jcl_creds`
- `payload/cmd/mainframe/generic_jcl`
- `payload/cmd/mainframe/apf_privesc_jcl`
- reverse shell payloads for mainframe

Treat Metasploit modules as **lab accelerators**, not blind PROD weapons.

---

## C. Defensive / audit tools (know them)

| Tool / product | Role |
|----------------|------|
| **IBM zSecure** | RACF analysis, monitoring, compliance |
| **Vanguard / other ISV** | Security administration & audit |
| **Broadcom cleanup / compliance tools** | ACF2/TSS/RACF hygiene |
| **SIEM connectors** | SMF → Splunk/QRadar/etc. |
| **IBM MFA for z/OS** | Multi-factor |
| **Crypto / ICSF admin tooling** | Key management |

As a pentester, request read-only reports from these tools when available — huge time saver.

---

## D. Documentation sources you will live in

- IBM Documentation (z/OS Security Server RACF books)
- IBM Redbooks (architecture & crypto)
- DISA STIGs for z/OS RACF / ACF2 / TSS
- Vendor CICS/IMS/Db2 security guides

---

## E. Lab options (how to practice)

### 1) Hercules + historical MVS (free, limited fidelity)
- **Hercules** emulator can run historical IBM OS distributions legally available via community archives (e.g. MVS 3.8j turnkey systems).
- Great for **JCL, TSO, 3270 muscle memory**.
- **Not** a perfect modern z/OS + RACF enterprise clone (licensing limits real z/OS on Hercules).

### 2) IBM official / cloud learning
- IBM Z trials / learning systems when available through IBM programs
- University / enterprise academic initiative access
- Employer TEST LPAR (best real practice)

### 3) Container workshops
- Community DEF CON workshops (e.g. mainframe overflow workshop materials published by researchers) for specific skills

### 4) Linux on s390x
- QEMU s390x or cloud s390x instances for Linux-on-Z practice (not full z/OS)

### 5) IBM i lab
- IBM i trial / cloud / publisher labs for 5250 security practice

---

## F. Recommended personal lab path

| Week | Goal |
|------|------|
| 1 | x3270 + Hercules MVS: logon, ISPF navigation, submit JCL |
| 2 | Learn datasets vs members; basic TSO commands |
| 3 | Read RACF concepts; practice LISTUSER/LISTDSD on any available system |
| 4 | Nmap TN3270 scripts against lab only |
| 5 | Study CICS concepts; watch public CICS hacking talks |
| 6 | Build a personal checklist from STIG + these notes |
| 7 | Practice practice against a legal target / employer TEST |
| 8 | Write a mock report from your lab findings |

---

## G. Useful skills outside “hacking tools”

| Skill | Why |
|-------|-----|
| **JCL reading** | Understand what jobs do before submitting |
| **REXX basics** | Enum scripts; automation |
| **EBCDIC awareness** | Avoid corrupted transfers |
| **ISPF navigation** | Speed |
| **SMF record types** | Blue-team conversations |
| **Networking (SNA basics)** | VTAM conversations |
| **SQL** | Db2 impact proofs |
| **MQ basics** | Channel findings |

---

## H. OPSEC & professional conduct tooling

- Separate engagement vault for evidence
- Redact account numbers / PANs in screenshots
- Time-stamp commands
- Change log of any modification
- Encrypted storage for customer data

---

## I. Sample authorized recon command set

```text
# Full TCP service discovery
nmap -sTV -p- --version-intensity 9 -Pn -oA out/full <target>

# TN3270 screenshots / banners
nmap -sV -p 23,992,2323 --script tn3270-screen -oA out/tn3270 <target>

# VTAM enum example shape (args vary by site)
nmap -p 23 --script vtam-enum --script-args brute.threads=3 <target>
```

Never paste real customer passwords into shared ticket systems.

---

## J. What not to run blindly in PROD

- High-thread password sprays
- NJE job floods
- Mass SURROGAT job storms
- Unreviewed APF elevation scripts that rewrite RACF permanently
- Anything that issues destructive operator commands

---

**Next:** [[09-Other-Platforms-IBM-i-and-Non-IBM]] · **Commands:** [[12-Command-Cheatsheet]]
