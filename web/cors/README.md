# CORS testing

## CLI — `cors_check.py` (recommended)

Sends real `Origin` headers from Python and inspects CORS response headers.

```bash
pip install -r ../../requirements.txt
python cors_check.py -u https://target.example/api/me
python cors_check.py -u https://target.example/api -o https://evil.example --preflight --json
```

Exit code **2** if any probe looks misconfigured (reflected origin, `null`, wildcard issues, etc.).

## Browser PoC — `index.html`

Host this page on an origin you control. Browsers **ignore** a forged `Origin` header set in JavaScript; the request uses the page’s origin. Use the CLI when you need arbitrary origins.
