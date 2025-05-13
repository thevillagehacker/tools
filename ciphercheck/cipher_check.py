import argparse
import csv
import requests
import re

# Extract cipher suite names from Nmap output
def extract_ciphers(nmap_file):
    with open(nmap_file, 'r') as file:
        lines = file.readlines()

    cipher_regex = re.compile(r"^\|\s+(TLS_.*WITH_[A-Z0-9_]+)")
    ciphers = []

    for line in lines:
        match = cipher_regex.search(line)
        if match:
            cipher = match.group(1).strip()
            ciphers.append(cipher)

    return ciphers

# Query ciphers with optional proxy
def query_cipher_strength(cipher_name, proxies=None):
    url = f"https://ciphersuite.info/api/cs/{cipher_name}"
    try:
        response = requests.get(url, proxies=proxies, timeout=10)
        if response.status_code == 200:
            data = response.json()
            cs = data.get(cipher_name)
            if cs:
                return {
                    "Cipher": cipher_name,
                    "Strength": cs.get("security", "unknown"),
                    "TLS": ", ".join(cs.get("tls_version", [])),
                    "KEX": cs.get("kex_algorithm", ""),
                    "Auth": cs.get("auth_algorithm", ""),
                    "Enc": cs.get("enc_algorithm", ""),
                    "Hash": cs.get("hash_algorithm", ""),
                }
            else:
                return {"Cipher": cipher_name, "Strength": "Not Found in Response"}
        else:
            return {"Cipher": cipher_name, "Strength": f"HTTP {response.status_code}"}
    except Exception as e:
        return {"Cipher": cipher_name, "Strength": f"Error: {str(e)}"}

# Save to CSV
def save_to_csv(results, output_file):
    fieldnames = ["Cipher", "Strength", "TLS", "KEX", "Auth", "Enc", "Hash"]
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)

# Main function with CLI args
def main():
    parser = argparse.ArgumentParser(description="Check TLS cipher strengths from Nmap output.")
    parser.add_argument('-f', '--file', required=True, help="Path to the Nmap output file")
    parser.add_argument('-o', '--output', required=True, help="Path to save CSV results")
    parser.add_argument('-p', '--proxy', help="HTTP proxy (e.g., http://127.0.0.1:8080)")

    args = parser.parse_args()
    ciphers = extract_ciphers(args.file)

    if not ciphers:
        print("[-] No cipher suites found in the Nmap file.")
        return

    proxies = {"http": args.proxy, "https": args.proxy} if args.proxy else None

    print(f"[+] Found {len(ciphers)} cipher(s). Querying API...\n")
    results = []

    for cipher in ciphers:
        result = query_cipher_strength(cipher, proxies=proxies)
        results.append(result)
        print(f"{cipher} -> Strength: {result['Strength']}")

    save_to_csv(results, args.output)
    print(f"\n[+] Results saved to: {args.output}")

if __name__ == "__main__":
    main()
