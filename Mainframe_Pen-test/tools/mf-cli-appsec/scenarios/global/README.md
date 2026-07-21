# Global scenario pack

These YAML files are **site-agnostic templates** for any **TN3270** mainframe estate
(IBM z/OS, z/VM, z/VSE, CICS/IMS/TSO, session managers, other 3270 hosts).

| File | Tag focus | Calibrate |
|------|-----------|-----------|
| `01_smoke_connect_login.yaml` | smoke, auth | optional assert text |
| `02_session_menu_select.yaml` | menu | `roles.app_code` |
| `03_hidden_app_access.yaml` | authz, vertical | `roles.hidden_app` |
| `04_idor_identifier.yaml` | idor | navigation + assert_not_contains |
| `05_vertical_function.yaml` | vertical | `roles.priv_function` |

## Use with any customer / LPAR

1. Copy `configs/site.example.yaml` → `configs/mysite.yaml` (host, port, platform).
2. Walk the path once in **wc3270**.
3. Edit `roles:` and uncomment site-specific steps.
4. Run:

```powershell
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml --dir scenarios\global --recursive --out out\global
```

Filter:

```powershell
.\bin\mf-cli-appsec.exe run-pack --config configs\mysite.yaml --dir scenarios\global --recursive --tags smoke,menu --out out\smoke
```

The legacy `scenarios/corppay/` folder remains as a **worked example** of a fully filled-in app pack.
