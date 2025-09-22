# ciphercheck
Check cipher suites for its stregths such as Secure, Insecure or Weak, etc.

## [Python Script](cipher_check.py)

## Usage
```sh
python cipher_check.py -f nmap_out.txt -o results.csv
```

### For Proxy
```sh
python cipher_check.py -f nmap_out.txt -o results.csv -p http://127.0.0.1:8080
```
> The output will be printed and written to a csv file.

### Output
![img](/assets/cipher_check_output.png)
