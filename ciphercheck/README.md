# ciphercheck
Check cipher suites for its stregths such as Secure, Insecure or Weak.

## Usage
- Use comma separated list to search for multiple cipher suites in the search bar.
- Use list of cipher suites from NMAP scan as text file and choose the file upload option to ananlyze it.

> ***Note*** The text file should only contain the cipher suites.

# [Python Script](cipher_check.py)

## Usage
```sh
python cipher_check.py -f nmap_out.txt -o results.csv
```
> The output will be printed and written to a csv file.
