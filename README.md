# 🛠️ Tools

> A curated collection of offensive security, reconnaissance, and bug bounty automation tools developed by **TheVillageHacker**.

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Shell](https://img.shields.io/badge/Bash-Scripts-success)
![Python](https://img.shields.io/badge/Python-3.x-blue)
![Go](https://img.shields.io/badge/Go-1.20+-00ADD8)
![Security](https://img.shields.io/badge/Purpose-Offensive%20Security-red)

---

## 📖 Overview

This repository contains a collection of lightweight security utilities designed to simplify common penetration testing, reconnaissance, and bug bounty workflows.

Most of the tools are focused on:

- 🌐 Web Reconnaissance
- 🔍 Attack Surface Enumeration
- 📂 Sensitive File Discovery
- ⚡ Automation
- 🛡️ Security Validation
- 🐞 Bug Bounty Hunting

Whether you're performing reconnaissance during a penetration test or automating repetitive tasks in a bug bounty engagement, these scripts are intended to save time and improve efficiency.

---

# 📦 Repository Structure

```
tools/
│
├── Bigfoot/               # Subdomain Takeover Detection
├── Bulk-Ping/             # Bulk ICMP Reachability Checker
├── Enum-HTTP-Methods/     # HTTP Method Enumeration
├── FileFetcher/           # Sensitive File Endpoint Discovery
├── ciphercheck/           # TLS Cipher Strength Analyzer
├── urlscrapper/           # Website URL Extractor (Go)
├── bug_bounty/            # Bug Bounty Helper Scripts
├── cors/                  # CORS Testing Files
├── utils/                 # Utility Scripts
└── assets/                # Images and Documentation Assets
```

---

# 🚀 Included Tools

## 🔍 Bigfoot

Detect potential **Subdomain Takeover** vulnerabilities.

### Features

- Scan single domains
- Scan multiple domains
- Checks common takeover services including:

- GitHub Pages
- Heroku
- AWS
- Bitbucket
- Shopify
- Tumblr
- Wordpress

Example:

```bash
./bigfoot.sh -d example.com
```

or

```bash
./bigfoot.sh -f domains.txt
```

---

## 📡 Bulk Ping

Quickly determine which hosts are alive.

Useful during:

- External Recon
- Internal Network Assessment
- Asset Validation

Example

```bash
./bulk_ping.sh -f hosts.txt
```

---

## 🌐 HTTP Method Enumeration

Enumerates supported HTTP methods exposed by web servers.

Useful for identifying:

- PUT
- DELETE
- TRACE
- CONNECT
- OPTIONS
- PATCH

Misconfigured HTTP methods often introduce security risks.

---

## 📂 FileFetcher

Automatically extracts interesting endpoints from URLs.

Searches for files such as:

- JavaScript
- JSON
- TXT
- PHP
- PDF
- DOCX
- XLSX
- CSV

Supports:

- Single target
- Multiple URLs
- WaybackURLs output

Example

```bash
./fetcher.sh -d example.com
```

or

```bash
./fetcher.sh -f urls.txt
```

---

## 🔐 CipherCheck

Analyze TLS cipher suites and classify them based on their security strength.

Categories include:

- Secure
- Weak
- Insecure

Example

```bash
python cipher_check.py \
-f nmap_output.txt \
-o results.csv
```

Supports proxy configuration as well.

---

## 🌍 URL Scrapper

A Go-based crawler that extracts URLs embedded within webpages.

Features

- Fast concurrent scraping
- Status code validation
- Output to file
- Lightweight binary

Example

```bash
urlscrapper -u https://example.com
```

With Status Codes

```bash
urlscrapper -u https://example.com -sc
```

Save Output

```bash
urlscrapper -u https://example.com -o output.txt
```

---

## 🐞 Bug Bounty Utilities

A collection of helper scripts to automate common bug bounty tasks.

Includes setup scripts, resolver lists, and workflow automation utilities.

---

## 🌐 CORS

Contains resources for testing Cross-Origin Resource Sharing (CORS) configurations.

Useful while validating:

- Origin Reflection
- Wildcard Origins
- Credential Misconfiguration

---

# ⚙️ Installation

Clone the repository

```bash
git clone https://github.com/thevillagehacker/tools.git

cd tools
```

Most Bash scripts simply require executable permissions.

```bash
chmod +x */*.sh
```

Python dependencies (where applicable)

```bash
pip install -r requirements.txt
```

Go tools

```bash
go build
```

or

```bash
go install
```

---

# 🧰 Recommended Environment

- Linux
- Kali Linux
- Parrot OS
- Ubuntu
- macOS (Most tools)

---

# 📋 Use Cases

These tools can assist with:

- Reconnaissance
- Bug Bounty Hunting
- Attack Surface Mapping
- External Asset Discovery
- Web Application Testing
- Infrastructure Validation
- TLS Security Review
- Sensitive Endpoint Discovery

---

# 🔄 Typical Workflow

```text
Target
   │
   ▼
Bulk Ping
   │
   ▼
Subdomain Enumeration
   │
   ▼
Bigfoot
   │
   ▼
HTTP Method Enumeration
   │
   ▼
URL Scrapper
   │
   ▼
FileFetcher
   │
   ▼
CipherCheck
   │
   ▼
Reporting
```

---

# 🤝 Contributing

Contributions are always welcome.

Feel free to:

- Report bugs
- Suggest improvements
- Submit pull requests
- Add new tools
- Improve documentation

---

# 💡 Future Improvements

- Docker support
- GitHub Actions CI
- Binary releases
- Better reporting
- Additional bug bounty utilities
- More recon automation
- Project-wide installation script
- Unit tests

---

# ⚠️ Disclaimer

These tools are intended for **authorized security testing, educational purposes, and research only**.

Users are responsible for ensuring they have permission before scanning or testing any systems. The author assumes no responsibility for misuse.

---

# ⭐ Support

If you find these tools useful, consider starring the repository.

It helps others discover the project and motivates future development.

---

## Author

**TheVillageHacker**

GitHub: https://github.com/thevillagehacker
