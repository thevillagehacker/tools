# 11 — Resources & References

Curated starting library. Prefer primary docs + reputable research over random blogs.

---

## A. Must-read research & methodology

| Resource | Why |
|----------|-----|
| [Securelist — Approach to mainframe pentesting on z/OS](https://securelist.com/zos-mainframe-pentesting/113427/) | End-to-end modern methodology, phases, RACF focus |
| [Securelist — Deconstructing RACF](https://securelist.com/zos-mainframe-pentesting-resource-access-control-facility/116873/) | Deeper RACF internals follow-on |
| [klsecservices/zos-mindset](https://github.com/klsecservices/zos-mindset) | Interactive path diagram companion |
| [hacksomeheavymetal/zOS pentesting.md](https://github.com/hacksomeheavymetal/zOS/blob/master/pentesting.md) | Crash-course practical notes |
| [Even More Awesome Mainframe Hacking](https://github.com/ricardojba/Even-More-Awesome-Mainframe-Hacking) | Huge link index (tools, talks, ports) |
| [Awesome-Mainframe-Hacking](https://github.com/samanL33T/Awesome-Mainframe-Hacking) | Original awesome-list |

---

## B. Commercial / industry overviews

| Resource | Why |
|----------|-----|
| [NetSPI Mainframe PT](https://www.netspi.com/netspi-ptaas/network-penetration-testing/mainframe/) | What professional assessments cover |
| [NetSPI — Hacking CICS](https://www.netspi.com/blog/technical-blog/mainframe-penetration-testing/hacking-cics-applications/) | Application-layer CICS angles |
| [Planet Mainframe — Why MF PT matters](https://planetmainframe.com/2025/10/mainframe-penetration-testing-why-it-matters-more-than-ever/) | Business motivation |
| [Reversec — attack paths to best practices](https://reversec.com/articles/mainframe-security-testing/) | Paths: surrogate, breakouts, hopping |
| [usd AG — Top 3 vulnerabilities in MF pentests](https://www.usd.de/en/top-3-vulnerabilities-pentests-mainframes/) | Common real findings |
| [DataStealth — Mainframe security controls guide](https://datastealth.io/blogs/mainframe-security-controls-a-practical-guide-to-z-os-security-systems) | Control-layer framing |

---

## C. Books

| Book | Use |
|------|-----|
| *Mainframe Basics for Security Professionals* (Pomerantz et al., IBM Press) | RACF-oriented security intro |
| *Introduction to the New Mainframe: z/OS Basics* (IBM Redbooks) | Platform literacy |
| *Hacking iSeries* (Shalom Carmel) | IBM i offensive perspective |
| Experts’ guides to IBM i security (Woodbury / Botz era) | IBM i defensive depth |
| PoC\|\|GTFO issue with NJE articles | NJE deep technical culture |

---

## D. IBM official documentation (authoritative)

Search IBM Docs for current versions:

- z/OS Security Server **RACF** Security Administrator's Guide  
- RACF Command Language Reference  
- z/OS UNIX Security  
- Communications Server (AT-TLS, TN3270, FTP)  
- CICS RACF Security Guide  
- Db2 for z/OS Administration / Security  
- ICSF / Crypto  
- IBM Z hardware technical introductions (z14/z15/z16/z17 Redbooks)

Redbooks portal: `https://www.redbooks.ibm.com`

---

## E. Hardening & compliance

| Resource | Use |
|----------|-----|
| DISA **z/OS RACF STIG** | Control checklist |
| DISA **z/OS ACF2 STIG** | ACF2 environments |
| DISA **z/OS TSS STIG** | Top Secret environments |
| STIG Viewer portals | Browse rules |
| Site security standards | Always override generic advice |

---

## F. Tools & code (links commonly cited)

| Item | Link / search key |
|------|-------------------|
| x3270 | `http://x3270.bgp.nu` |
| mainframed tools | GitHub `mainframed` |
| ayoul3 CICSpwn / Privesc | GitHub `ayoul3` |
| BIRP | GitHub `sensepost/birp` |
| NJElib | GitHub `zedsec390/NJElib` |
| Metasploit mainframe modules | Rapid7 MSF `mainframe` |
| Hercules emulator | `http://www.hercules-390.org` |
| Nmap tn3270 scripts | Nmap NSE documentation |

---

## G. Talks & playlists (high signal)

Search YouTube / conference sites for:

| Speaker / handle | Topics |
|------------------|--------|
| **Soldier of FORTRAN** (@mainframed767, Philip Young) | Broad mainframe hacking series, NJE, history |
| **Bigendian Smalls** (Chad Rikansrud) | RE, ransomware discussions, advanced |
| **ayoul3** (Ayoub Elaassal) | CICS, post-exploit, SPECIAL |
| Sensepost TN3270 talks | Green-screen app flaws |
| Mark Wilson / Vertali | Integrity, professional testing |
| DEF CON / Black Hat / NorthSec mainframe talks | Various years 2013–2022+ |

Awesome-list playlists curated under Soldier of FORTRAN are excellent binge material.

---

## H. Training options

| Option | Notes |
|--------|-------|
| Employer TEST LPAR access | Best ROI |
| Evil Mainframe / specialist courses | Commercial MF hacking training (verify current offerings) |
| IBM Z digital learning | Platform fundamentals |
| Hercules home lab | Free skill-building |
| DEF CON workshop materials | Published containers/labs in some years |

---

## I. Default accounts & wordlists (lab only)

Community repos maintain:

- Default TSO-oriented accounts lists  
- Default CICS transaction lists  

Example path referenced publicly: `hacksomeheavymetal/zOS` default files.

**Never** assume defaults work on production; treat as historical hygiene checks.

---

## J. IBM i specific links

| Resource | Notes |
|----------|-------|
| Community “Hack the Legacy” materials | IBM i orientation |
| Black Hat EU Shalom Carmel AS/400 decks | Classic |
| hack400tool | GitHub tool suite |
| IBM i Security Reference | Official hardening |

---

## K. Vocabulary quick links

- Full acronym lists in community zOS repos (`vocabulary.md` style files)
- IBM Glossary in official docs

---

## L. Suggested 30-day reading plan

| Day range | Material |
|-----------|----------|
| 1–3 | These notes 01–04 |
| 4–7 | z/OS Basics Redbook chapters + RACF intro book |
| 8–10 | Securelist z/OS pentest article + mindset diagram |
| 11–14 | Watch 5 Soldier of FORTRAN talks |
| 15–18 | CICS NetSPI post + ayoul3 CICS talk |
| 19–21 | STIG skim (APF, SURROGAT, passwords, started tasks) |
| 22–25 | Hercules lab navigation |
| 26–28 | Tools setup (x3270, nmap scripts) |
| 29–30 | Write your own 1-page methodology cheat sheet |

---

## M. How to stay current

- SHARE / GSE conference materials  
- IBM Z security announcements  
- Broadcom mainframe security blogs  
- NetSPI / specialist vendor blogs  
- CVE feeds filtered for z/OS, CICS, Db2, WebSphere, IBM HTTP Server  

---

## N. Ethics reminder

Mainframes process real money and personal data. Unauthorized access is a crime. These notes are for:

- Defensive security engineering  
- Authorized penetration testing  
- Lab learning on legal systems  

---

## Related notes in this folder

- [[00-README]]
- [[01-Introduction-and-Architecture]]
- [[02-Operating-Systems]]
- [[03-Security-Architecture-and-Controls]]
- [[04-Attack-Surface-and-Services]]
- [[05-Pentest-Methodology]]
- [[06-Privilege-Escalation-and-Misconfigs]]
- [[07-CICS-IMS-DB2-Application-Testing]]
- [[08-Tools-and-Lab-Setup]]
- [[09-Other-Platforms-IBM-i-and-Non-IBM]]
- [[10-Checklist-and-Reporting]]
- [[12-Command-Cheatsheet]]
- [[13-Console-CLI-Application-Security-Testing]]
