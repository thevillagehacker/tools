# Bug bounty recon pipeline

## `run.sh` (v2)

Automated recon against `scope/<id>/roots.txt`.

```bash
mkdir -p scope/example
echo example.com > scope/example/roots.txt
chmod +x run.sh
./run.sh example
./run.sh example --passive
./run.sh example --dns-only
```

### Stages

1. Subdomain enum (haktrails, subfinder, alterx)
2. Resolve (puredns / dnsx) → IPs
3. Optional nmap (skip with `--passive`)
4. Live HTTP (`httpx`)
5. Crawl (katana / gospider)
6. Takeover checks via repo **Bigfoot**
7. Interesting URLs via wayback + **FileFetcher**

Results land in `scans/<id>-<timestamp>/`.

### Required tools

`subfinder`, `dnsx`, `httpx`, `anew`, `jq`

### Optional tools

`haktrails`, `alterx`, `puredns`, `nmap`, `katana`, `gospider`, `waybackurls`, `wget`/`curl`

Install helpers:

```bash
sudo ./setup.sh
```

`setup.sh` prepares a workspace under `~/bug_bounty` and installs common Go/apt tools. `scan.sh` is created as a symlink to `run.sh` for compatibility.
