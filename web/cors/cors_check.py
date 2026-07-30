#!/usr/bin/env python3
"""
CORS misconfiguration checker (server-side).

Browsers do not allow page JavaScript to spoof the Origin header.
This CLI sends controllable Origin values and inspects ACAO/ACAC/ACAH.

Also see index.html for a PoC page that must be hosted on an attacker origin.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

VERSION = "1.0"


def origins_to_test(target: str, custom: Optional[List[str]]) -> List[str]:
    parsed = urlparse(target)
    host = parsed.hostname or "example.com"
    scheme = parsed.scheme or "https"
    defaults = [
        "https://evil.example",
        "http://evil.example",
        "null",
        f"{scheme}://attacker.{host}",
        f"{scheme}://{host}.evil.example",
        f"{scheme}://evil{host}",
    ]
    if custom:
        return custom
    return defaults


def check_cors(
    url: str,
    origin: str,
    method: str = "GET",
    with_creds: bool = False,
    headers: Optional[Dict[str, str]] = None,
    timeout: float = 10.0,
    verify: bool = True,
    preflight: bool = False,
) -> Dict[str, Any]:
    req_headers = {"Origin": origin, "User-Agent": f"cors-check/{VERSION}"}
    if headers:
        req_headers.update(headers)

    session = requests.Session()
    result: Dict[str, Any] = {
        "url": url,
        "origin": origin,
        "method": method,
        "preflight": preflight,
        "credentials_requested": with_creds,
    }

    try:
        if preflight:
            pf_headers = {
                **req_headers,
                "Access-Control-Request-Method": method,
                "Access-Control-Request-Headers": "content-type,authorization",
            }
            resp = session.options(
                url,
                headers=pf_headers,
                timeout=timeout,
                verify=verify,
                allow_redirects=False,
            )
        else:
            resp = session.request(
                method,
                url,
                headers=req_headers,
                timeout=timeout,
                verify=verify,
                allow_redirects=False,
            )

        acao = resp.headers.get("Access-Control-Allow-Origin")
        acac = resp.headers.get("Access-Control-Allow-Credentials")
        acah = resp.headers.get("Access-Control-Allow-Headers")
        acam = resp.headers.get("Access-Control-Allow-Methods")

        result.update(
            {
                "status": resp.status_code,
                "acao": acao,
                "acac": acac,
                "acah": acah,
                "acam": acam,
            }
        )

        vulnerable = False
        reasons: List[str] = []

        if acao == "*":
            reasons.append("ACAO is wildcard *")
            if (acac or "").lower() == "true":
                reasons.append("wildcard ACAO with credentials (invalid/misconfigured)")
                vulnerable = True
            else:
                # wildcard without creds is often intentional but still worth noting
                vulnerable = True

        if acao == origin:
            reasons.append("reflected Origin in ACAO")
            vulnerable = True
            if (acac or "").lower() == "true":
                reasons.append("ACAC true with reflected origin (high impact if auth cookies)")

        if origin == "null" and acao == "null":
            reasons.append("null origin allowed")
            vulnerable = True

        result["vulnerable"] = vulnerable
        result["reasons"] = reasons
        result["error"] = None
    except requests.RequestException as exc:
        result["error"] = str(exc)
        result["vulnerable"] = False
        result["reasons"] = []

    return result


def print_result(r: Dict[str, Any], quiet: bool = False) -> None:
    if r.get("error"):
        print(f"[-] origin={r['origin']!r} error={r['error']}")
        return

    flag = "VULN" if r.get("vulnerable") else "ok"
    reasons = ", ".join(r.get("reasons") or []) or "-"
    print(
        f"[{flag}] origin={r['origin']!r} status={r.get('status')} "
        f"ACAO={r.get('acao')!r} ACAC={r.get('acac')!r} reasons={reasons}"
    )
    if not quiet and r.get("acam"):
        print(f"       Allow-Methods={r.get('acam')!r} Allow-Headers={r.get('acah')!r}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Server-side CORS misconfiguration checker (sets Origin properly)."
    )
    parser.add_argument("-u", "--url", required=True, help="Target URL")
    parser.add_argument(
        "-o",
        "--origin",
        action="append",
        dest="origins",
        help="Origin to test (repeatable). Default: built-in evil/null/subdomain set",
    )
    parser.add_argument("-m", "--method", default="GET", help="HTTP method (default GET)")
    parser.add_argument(
        "--credentials",
        action="store_true",
        help="Note credentials concern (Origin still sent; use browser PoC for cookie tests)",
    )
    parser.add_argument("--preflight", action="store_true", help="Send OPTIONS preflight")
    parser.add_argument("-H", "--header", action="append", help="Extra header Key:Value")
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("-k", "--insecure", action="store_true")
    parser.add_argument("--json", action="store_true", help="JSON lines output")
    parser.add_argument("-q", "--quiet", action="store_true")
    args = parser.parse_args()

    extra: Dict[str, str] = {}
    if args.header:
        for h in args.header:
            if ":" in h:
                k, v = h.split(":", 1)
                extra[k.strip()] = v.strip()

    origins = origins_to_test(args.url, args.origins)
    any_vuln = False

    for origin in origins:
        r = check_cors(
            args.url,
            origin,
            method=args.method.upper(),
            with_creds=args.credentials,
            headers=extra or None,
            timeout=args.timeout,
            verify=not args.insecure,
            preflight=args.preflight,
        )
        if r.get("vulnerable"):
            any_vuln = True
        if args.json:
            print(json.dumps(r))
        else:
            print_result(r, quiet=args.quiet)

    return 0 if not any_vuln else 2


if __name__ == "__main__":
    sys.exit(main())
