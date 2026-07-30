#!/usr/bin/env python3
"""
CipherCheck v2 — classify TLS cipher suites from Nmap ssl-enum-ciphers output.
Uses ciphersuite.info API with a local fallback map when offline.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional, Set

import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

VERSION = "2.0"

# Local fallback when API is unreachable (strength labels approximate IANA/modern guidance)
LOCAL_STRENGTH: Dict[str, str] = {
    "NULL": "insecure",
    "EXPORT": "insecure",
    "RC4": "insecure",
    "DES": "insecure",
    "3DES": "weak",
    "MD5": "weak",
    "CBC": "weak",  # often weak under Lucky13/POODLE-class issues depending on TLS version
    "ANON": "insecure",
    "ADH": "insecure",
    "AEAD": "secure",
    "GCM": "secure",
    "CHACHA20": "secure",
    "POLY1305": "secure",
}

CIPHER_LINE_RES = [
    # nmap ssl-enum-ciphers table
    re.compile(r"^\|\s+(TLS_[A-Z0-9_]+)\s+\("),
    re.compile(r"^\|\s+(TLS_[A-Z0-9_]+)\s"),
    re.compile(r"^\|\s+(TLS_.*WITH_[A-Z0-9_]+)"),
    # sometimes without leading |
    re.compile(r"\b(TLS_[A-Z0-9_]{8,})\b"),
]


def extract_ciphers(nmap_file: str) -> List[str]:
    with open(nmap_file, "r", encoding="utf-8", errors="ignore") as fh:
        lines = fh.readlines()

    found: List[str] = []
    seen: Set[str] = set()
    for line in lines:
        for rx in CIPHER_LINE_RES:
            m = rx.search(line)
            if m:
                cipher = m.group(1).strip().rstrip(":")
                if cipher.startswith("TLS_") and cipher not in seen:
                    seen.add(cipher)
                    found.append(cipher)
                break
    return found


def local_classify(cipher_name: str) -> Dict[str, str]:
    upper = cipher_name.upper()
    strength = "unknown"
    if any(x in upper for x in ("NULL", "EXPORT", "RC4", "DES_CBC", "_DES_", "ANON", "ADH", "AECDH")):
        strength = "insecure"
    elif "3DES" in upper or "MD5" in upper or "_CBC_" in upper or upper.endswith("_CBC_SHA"):
        strength = "weak"
    elif any(x in upper for x in ("GCM", "CHACHA20", "POLY1305", "AES_128_GCM", "AES_256_GCM")):
        strength = "secure"
    elif "AES" in upper:
        strength = "recommended" if "GCM" in upper else "weak"
    return {
        "Cipher": cipher_name,
        "Strength": strength,
        "TLS": "",
        "KEX": "",
        "Auth": "",
        "Enc": "",
        "Hash": "",
        "Source": "local",
    }


def query_cipher_strength(
    cipher_name: str,
    proxies: Optional[dict],
    verify: bool,
    timeout: float,
) -> Dict[str, str]:
    url = f"https://ciphersuite.info/api/cs/{cipher_name}"
    try:
        response = requests.get(url, proxies=proxies, timeout=timeout, verify=verify)
        if response.status_code == 200:
            data = response.json()
            cs = data.get(cipher_name) or next(iter(data.values()), None)
            if isinstance(cs, dict):
                tls = cs.get("tls_version") or []
                if isinstance(tls, list):
                    tls_s = ", ".join(tls)
                else:
                    tls_s = str(tls)
                return {
                    "Cipher": cipher_name,
                    "Strength": str(cs.get("security", "unknown")),
                    "TLS": tls_s,
                    "KEX": str(cs.get("kex_algorithm", "")),
                    "Auth": str(cs.get("auth_algorithm", "")),
                    "Enc": str(cs.get("enc_algorithm", "")),
                    "Hash": str(cs.get("hash_algorithm", "")),
                    "Source": "api",
                }
            return {**local_classify(cipher_name), "Strength": "Not Found in Response"}
        return {**local_classify(cipher_name), "Strength": f"HTTP {response.status_code} (local fallback used)"}
    except Exception:
        return local_classify(cipher_name)


def save_to_csv(results: List[Dict[str, str]], output_file: str) -> None:
    fieldnames = ["Cipher", "Strength", "TLS", "KEX", "Auth", "Enc", "Hash", "Source"]
    with open(output_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(results)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=f"CipherCheck v{VERSION} — TLS cipher strength from Nmap output."
    )
    parser.add_argument("-f", "--file", required=True, help="Path to Nmap output file")
    parser.add_argument("-o", "--output", required=True, help="Path to save CSV results")
    parser.add_argument("-p", "--proxy", help="HTTP proxy (e.g. http://127.0.0.1:8080)")
    parser.add_argument("-k", "--insecure", action="store_true", help="Disable TLS verify for API calls")
    parser.add_argument("--local-only", action="store_true", help="Do not call remote API")
    parser.add_argument("-c", "--concurrency", type=int, default=8, help="Parallel API lookups")
    parser.add_argument("--timeout", type=float, default=10.0, help="API timeout seconds")
    args = parser.parse_args()

    ciphers = extract_ciphers(args.file)
    if not ciphers:
        print("[-] No cipher suites found in the Nmap file.", file=sys.stderr)
        return 1

    proxies = {"http": args.proxy, "https": args.proxy} if args.proxy else None
    print(f"[+] Found {len(ciphers)} cipher(s). Classifying...\n")

    results: List[Dict[str, str]] = []
    if args.local_only:
        for cipher in ciphers:
            result = local_classify(cipher)
            results.append(result)
            print(f"{cipher} -> Strength: {result['Strength']} (local)")
    else:
        with ThreadPoolExecutor(max_workers=max(1, args.concurrency)) as pool:
            futs = {
                pool.submit(
                    query_cipher_strength,
                    cipher,
                    proxies,
                    not args.insecure,
                    args.timeout,
                ): cipher
                for cipher in ciphers
            }
            for fut in as_completed(futs):
                result = fut.result()
                results.append(result)
                print(f"{result['Cipher']} -> Strength: {result['Strength']} [{result.get('Source', '')}]")
                time.sleep(0)  # yield

        # stable order like input
        order = {c: i for i, c in enumerate(ciphers)}
        results.sort(key=lambda r: order.get(r["Cipher"], 9999))

    save_to_csv(results, args.output)
    print(f"\n[+] Results saved to: {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
