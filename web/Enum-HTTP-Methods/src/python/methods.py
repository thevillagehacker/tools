#!/usr/bin/env python3
"""HTTP method enumeration — Python port (v2)."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Dict, List, Optional, Tuple

import requests
import urllib3
from termcolor import colored

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

VERSION = "2.0"
METHODS = ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "TRACE", "CONNECT"]
DANGEROUS = {"PUT", "DELETE", "TRACE", "CONNECT", "PATCH"}


def print_banner() -> None:
    print(
        colored(
            rf"""
          _|_|_  _   .|| _  _  _ |_  _  _|  _  _
           | | |(/_\/|||(_|(_|(/_| |(_|(_|<(/_|
                            _|
                  ------------------
               ~ |Do Hacks to Secure| ~
                  ------------------
           HTTP Method Enumeration v{VERSION}
""",
            "green",
        )
    )


def parse_headers(raw: Optional[str]) -> Dict[str, str]:
    headers: Dict[str, str] = {}
    if not raw:
        return headers
    for part in raw.split(","):
        part = part.strip()
        if ":" not in part:
            continue
        key, value = part.split(":", 1)
        headers[key.strip()] = value.strip()
    return headers


def load_targets(host: Optional[str], list_path: Optional[str]) -> List[str]:
    targets: List[str] = []
    if host:
        targets.append(host)
    if list_path:
        with open(list_path, encoding="utf-8", errors="ignore") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                targets.append(line)
    return targets


def probe(
    url: str,
    method: str,
    headers: Dict[str, str],
    timeout: float,
    verify: bool,
    allow_redirects: bool,
) -> Tuple[Optional[int], str, str, Optional[str]]:
    try:
        resp = requests.request(
            method,
            url,
            headers=headers,
            timeout=timeout,
            verify=verify,
            allow_redirects=allow_redirects,
        )
        allow = resp.headers.get("Allow") or resp.headers.get("Access-Control-Allow-Methods") or ""
        return resp.status_code, resp.reason or "", allow, None
    except requests.RequestException as exc:
        return None, "", "", str(exc)


def main() -> int:
    parser = argparse.ArgumentParser(description="Enumerate supported HTTP methods on a target.")
    parser.add_argument("-u", "--host", help="Target URL")
    parser.add_argument("-l", "--list", help="File of target URLs")
    parser.add_argument(
        "--headers",
        help="Extra headers 'Key:Value,Key2:Value2'",
    )
    parser.add_argument("--auth", help="Authorization header value")
    parser.add_argument("--timeout", type=float, default=10.0, help="Request timeout seconds")
    parser.add_argument("-k", "--insecure", action="store_true", help="Skip TLS verification")
    parser.add_argument(
        "--follow-redirects",
        action="store_true",
        help="Follow redirects (default: do not)",
    )
    parser.add_argument("--json", action="store_true", help="JSON lines output")
    parser.add_argument("-q", "--silent", action="store_true", help="Suppress banner")
    args = parser.parse_args()

    targets = load_targets(args.host, args.list)
    if not targets:
        parser.error("provide -u/--host or -l/--list")

    if not args.silent and not args.json:
        print_banner()

    headers = parse_headers(args.headers)
    if args.auth:
        headers["Authorization"] = args.auth
    headers.setdefault("User-Agent", f"enum-http-methods/{VERSION}")

    for url in targets:
        if not args.json:
            print("[+] Host:", colored(url, "yellow"))

        for method in METHODS:
            code, reason, allow, err = probe(
                url,
                method,
                headers,
                timeout=args.timeout,
                verify=not args.insecure,
                allow_redirects=args.follow_redirects,
            )
            if err:
                if args.json:
                    print(json.dumps({"url": url, "method": method, "error": err}))
                else:
                    print(f"{method}: {colored('request failed: ' + err, 'red')}")
                continue

            interesting = bool(code and 200 <= code < 300 and method in DANGEROUS)
            if args.json:
                print(
                    json.dumps(
                        {
                            "url": url,
                            "method": method,
                            "status": code,
                            "status_text": reason,
                            "allow": allow,
                            "interesting": interesting,
                        }
                    )
                )
                continue

            if code is None:
                color = "red"
            elif interesting:
                color = "red"
            elif 200 <= code < 300:
                color = "green"
            elif 300 <= code < 400:
                color = "yellow"
            elif 400 <= code < 500:
                color = "red"
            else:
                color = "grey"

            suffix = "  ← review (dangerous method allowed?)" if interesting else ""
            print(f"{method}: {colored(str(code), color)} {reason}{suffix}")
            if method == "OPTIONS" and allow:
                print(f"         Allow: {colored(allow, 'magenta')}")

        if not args.json:
            print()

    return 0


if __name__ == "__main__":
    sys.exit(main())
