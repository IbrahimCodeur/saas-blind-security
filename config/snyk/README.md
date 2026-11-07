# Snyk configuration

Snyk is **optional**. Without a `SNYK_TOKEN`, the Snyk workflow and local Snyk checks are skipped and every
other check still runs.

1. Create a Snyk account and copy your API token (Account settings → Auth Token).
2. GitHub: *Settings → Secrets and variables → Actions → New repository secret* → `SNYK_TOKEN`.
3. Local: `export SNYK_TOKEN=...` in your shell (never commit it) or run `snyk auth`.

What runs (`scripts/security-check.sh` and `.github/workflows/snyk.yml`):

| Command | Product | Notes |
|---|---|---|
| `snyk test --all-projects` | Snyk Open Source | Dependencies. Python projects need dependencies installed first. |
| `snyk code test` | Snyk Code (SAST) | Must be enabled in your Snyk organisation settings; otherwise reported as *skipped*. |
| `snyk iac test` | Snyk IaC | Only when Terraform / Kubernetes / Dockerfiles are present. |

Blocking threshold: repository variable `SBS_FAIL_ON_SEVERITY` (default `HIGH`).

Ignoring a finding: use a `.snyk` policy file at your project root (see `snyk-policy.example`) with a reason
and an expiry date. Never ignore without a justification.
