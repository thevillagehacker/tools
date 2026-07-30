# HTTP method enumeration

Probe GET/HEAD/POST/PUT/PATCH/DELETE/OPTIONS/TRACE/CONNECT. Dangerous methods that return 2xx are highlighted. OPTIONS prints `Allow` when present. Redirects are not followed by default.

## Go

```bash
cd src/go
go build -o enum-http-methods .
./enum-http-methods -u https://example.com/
./enum-http-methods -l urls.txt --json -auth 'Bearer TOKEN'
```

## Python

```bash
pip install -r ../../../requirements.txt
python src/python/methods.py -u https://example.com/
python src/python/methods.py -l urls.txt --json
```
