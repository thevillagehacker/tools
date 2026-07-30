# Tools

> Offensive security, reconnaissance, and bug bounty utilities by **TheVillageHacker**.

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Shell](https://img.shields.io/badge/Bash-Scripts-success)
![Python](https://img.shields.io/badge/Python-3.x-blue)
![Go](https://img.shields.io/badge/Go-1.21+-00ADD8)
![Security](https://img.shields.io/badge/Purpose-Offensive%20Security-red)

---

## Overview

Lightweight helpers for:

- Web reconnaissance and attack-surface mapping
- Subdomain takeover fingerprinting
- Sensitive URL / file triage
- HTTP method and CORS checks
- TLS cipher review
- End-to-end bug bounty recon automation

Use only on systems you are authorized to test.

---

## Repository structure

```text
tools/
├── recon/
│   ├── Bigfoot/           # Subdomain takeover detection
│   ├── FileFetcher/       # Interesting URL / sensitive path triage
│   └── urlscrapper/       # Page URL extractor (Go)
├── web/
│   ├── cors/              # CORS CLI + browser PoC page
│   └── Enum-HTTP-Methods/ # HTTP verb enumeration (Go + Python)
├── network/
│   ├── Bulk-Ping/         # Parallel host liveness
│   └── ciphercheck/       # TLS cipher strength from Nmap output
├── bug_bounty/
│   ├── run.sh             # Full recon pipeline
│   ├── setup.sh           # Install common recon tooling
│   └── resolvers.txt
├── Mainframe_Pen-test/    # Mainframe notes + mf-cli-appsec
├── utils/                 # Shell / Oh My Posh helpers
├── requirements.txt       # Python deps for Python tools
└── README.md
```

---

## Quick start

```bash
git clone https://github.com/thevillagehacker/tools.git
cd tools

# Bash tools
chmod +x recon/*/*.sh network/*/*.sh bug_bounty/*.sh

# Python tools
pip install -r requirements.txt

# Go tools
cd recon/urlscrapper && go build -o urlscrapper . && cd ../..
cd web/Enum-HTTP-Methods/src/go && go build -o enum-http-methods . && cd ../../../..
```

**Recommended environment:** Linux (Kali/Parrot/Ubuntu), or WSL. macOS works for most scripts if `bash` ≥ 4 and coreutils/`curl` are available.

---

## Tools

### Bigfoot (`recon/Bigfoot/`) — subdomain takeover

HTTP(S) fingerprinting against a large service list (`fingerprints.txt`), optional CNAME hints via `dig`/`host`, concurrent bulk scans.

```bash
./recon/Bigfoot/bigfoot.sh -d dangling.example.com
./recon/Bigfoot/bigfoot.sh -f subs.txt --only-vuln -o findings.txt
./recon/Bigfoot/bigfoot.sh -f subs.txt --json -o findings.jsonl
```

| Flag | Purpose |
|------|---------|
| `-d` / `-f` | Single host or host list |
| `-c N` | Concurrency (default 10) |
| `--only-vuln` | Print only possible takeovers |
| `--json` | JSON lines |
| `--http-only` | Skip HTTPS |
| `--no-cname` | Skip CNAME lookup |

Requires **curl** (or httpie). Edit `fingerprints.txt` to add providers (`service\|substring`).

---

### FileFetcher (`recon/FileFetcher/`) — interesting endpoints

Pulls URLs via **waybackurls** or **gau** (`-d`), or classifies an existing list (`-f`). Buckets JS, PHP, JSON, docs, config/secrets, backups, API docs.

```bash
./recon/FileFetcher/fetcher.sh -d example.com
./recon/FileFetcher/fetcher.sh -f urls.txt --probe -o out/example
```

| Flag | Purpose |
|------|---------|
| `-d` / `-f` | Domain (passive URLs) or file |
| `-o DIR` | Output directory (default `./results`) |
| `--probe` | Live-check interesting URLs (`httpx` or `curl`) |

---

### URL Scrapper (`recon/urlscrapper/`) — page link extraction

Go tool: HTML attribute crawl + regex fallback, relative URL resolution, optional concurrent status checks.

```bash
cd recon/urlscrapper
go build -o urlscrapper .
./urlscrapper -u https://example.com
./urlscrapper -u https://example.com -sc -c 20 -o links.txt
./urlscrapper -u https://example.com --same-host -silent -o scoped.txt
```

| Flag | Purpose |
|------|---------|
| `-u` | Target URL (**required**) |
| `-o` | Output file |
| `-sc` | Status-code check |
| `-c` | Status-check workers |
| `--same-host` | Keep same hostname only |
| `-timeout` | HTTP timeout |

---

### HTTP method enumeration (`web/Enum-HTTP-Methods/`)

Probes common verbs, highlights dangerous methods that return 2xx, prints `Allow` / `Access-Control-Allow-Methods` on OPTIONS. Does **not** follow redirects by default.

**Go:**

```bash
cd web/Enum-HTTP-Methods/src/go
go build -o enum-http-methods .
./enum-http-methods -u https://example.com/
./enum-http-methods -l urls.txt -auth 'Bearer TOKEN' --json
```

**Python:**

```bash
python web/Enum-HTTP-Methods/src/python/methods.py -u https://example.com/
python web/Enum-HTTP-Methods/src/python/methods.py -l urls.txt --json
```

---

### CORS (`web/cors/`)

1. **CLI (recommended)** — sets `Origin` server-side and inspects ACAO/ACAC:

```bash
python web/cors/cors_check.py -u https://target/api/me
python web/cors/cors_check.py -u https://target/api -o https://evil.example --preflight --json
```

Exit code `2` if any check looks vulnerable.

2. **`index.html`** — browser PoC. Host it on an origin you control; the browser sends *that* origin (JS cannot forge `Origin`). Use the CLI for arbitrary origins.

---

### Bulk-Ping (`network/Bulk-Ping/`)

Parallel ICMP checks; optional TCP fallback when ICMP is filtered.

```bash
./network/Bulk-Ping/bulk_ping.sh -f hosts.txt
./network/Bulk-Ping/bulk_ping.sh -f hosts.txt -c 100 --tcp 443
```

Writes `results/up.txt`, `down.txt`, `summary.txt`.

---

### CipherCheck (`network/ciphercheck/`)

Parses Nmap `ssl-enum-ciphers` output, classifies via [ciphersuite.info](https://ciphersuite.info) with a **local fallback**.

```bash
python network/ciphercheck/cipher_check.py -f nmap_ssl.txt -o results.csv
python network/ciphercheck/cipher_check.py -f nmap_ssl.txt -o results.csv --local-only
python network/ciphercheck/cipher_check.py -f nmap_ssl.txt -o results.csv -p http://127.0.0.1:8080
```

---

### Bug bounty pipeline (`bug_bounty/run.sh`)

End-to-end recon:

1. Subdomains (haktrails, subfinder, alterx)
2. Resolve (puredns / dnsx)
3. Optional nmap
4. Live HTTP (httpx)
5. Crawl (katana / gospider)
6. Takeover (Bigfoot)
7. Interesting URLs (wayback + FileFetcher)

```bash
cd bug_bounty   # or copy run.sh into your workspace
mkdir -p scope/example
echo example.com > scope/example/roots.txt
./run.sh example
./run.sh example --passive --no-crawl
./run.sh example --dns-only
./run.sh          # interactive target + roots
```

| Flag | Purpose |
|------|---------|
| `--passive` / `--skip-nmap` | No nmap |
| `--dns-only` | Stop after resolve |
| `--no-crawl` / `--no-takeover` / `--no-files` | Skip stages |
| `--debug` | Extra logs |

**Environment setup** (Go tools, pdtm, zsh helpers):

```bash
sudo ./bug_bounty/setup.sh
```

`setup.sh` installs common binaries and prepares `~/bug_bounty` with `run.sh` (and a `scan.sh` symlink for older muscle memory).

---

## Typical workflow

```text
roots.txt
    │
    ▼
run.sh  (or manual chain)
    │
    ├─► subfinder / haktrails / puredns
    ├─► Bulk-Ping or httpx
    ├─► Bigfoot (takeovers)
    ├─► urlscrapper / katana / FileFetcher
    ├─► Enum-HTTP-Methods / cors_check
    └─► CipherCheck (from nmap TLS output)
```

---

## Dependencies (summary)

| Tool | Needs |
|------|--------|
| Bigfoot | `curl` (or httpie); optional `dig`/`host` |
| FileFetcher | `waybackurls` or `gau`; optional `httpx` |
| urlscrapper | Go 1.21+ |
| Enum-HTTP-Methods | Go **or** Python + `requests`, `termcolor` |
| cors_check | Python + `requests` |
| CipherCheck | Python + `requests` |
| Bulk-Ping | `ping`; bash `/dev/tcp` for `--tcp` |
| run.sh | `subfinder`, `dnsx`, `httpx`, `anew`, `jq`; optional puredns, nmap, katana, gospider, waybackurls, haktrails, alterx |

```bash
pip install -r requirements.txt
```

---

## Mainframe notes

`Mainframe_Pen-test/` contains methodology docs and **mf-cli-appsec** (Go). See that directory’s README for build and usage. It is separate from the web recon toolkit.

---

## Contributing

Bug reports, fingerprint additions (`recon/Bigfoot/fingerprints.txt`), and PRs are welcome.

---

## Disclaimer

For **authorized** security testing, education, and research only. You are responsible for permission and legal compliance. The author assumes no liability for misuse.

---

## Author

**TheVillageHacker** — [GitHub](https://github.com/thevillagehacker)
