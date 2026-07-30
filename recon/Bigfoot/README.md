# Bigfoot v3

Subdomain takeover fingerprint scanner.

## Usage

```bash
chmod +x bigfoot.sh
./bigfoot.sh -d host.example.com
./bigfoot.sh -f hosts.txt --only-vuln -o findings.txt
./bigfoot.sh -f hosts.txt --json -c 20
```

## Fingerprints

Edit `fingerprints.txt` (format: `Service Name|body substring`). Built-in defaults are used if the file is missing.

## Notes

- Prefer **curl**. HTTPie works as a fallback.
- CNAME is shown when `dig` or `host` is available; absence of a match does not prove safety.
- Confirm takeovers manually before reporting (DNS, provider claim flow, impact).
