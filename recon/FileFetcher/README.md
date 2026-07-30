# FileFetcher v3

Classify interesting and potentially sensitive URLs from wayback/gau or a local list.

## Usage

```bash
chmod +x fetcher.sh
./fetcher.sh -d example.com
./fetcher.sh -f urls.txt -o out/example --probe
```

## Outputs

| File | Content |
|------|---------|
| `all_urls.txt` | Deduped input set |
| `js.txt` | JS / source maps |
| `php.txt` | PHP endpoints |
| `json.txt` | JSON / YAML |
| `text.txt` | txt / log / md |
| `docs.txt` | pdf, office, csv |
| `config_secrets.txt` | env, git, configs, keys |
| `backups.txt` | bak, sql, archives |
| `api_docs.txt` | swagger, graphql, actuators |
| `other_sensitive.txt` | Union of high-value sets |
| `live_interesting.txt` | With `--probe` |

## Dependencies

- `-d` mode: `waybackurls` or `gau`
- `--probe`: `httpx` (preferred) or `curl`
