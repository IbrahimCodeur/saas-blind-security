# Configuration

## Configuration file

`sbs.conf` uses `KEY=value` lines. It is **parsed, not executed**: only `SBS_*` keys are read, values are
taken literally. Environment variables with the same name take precedence. Files read (first value wins):
environment → `<project>/.saas-blind-security/sbs.conf` → `<project>/config/sbs.conf` → `<framework>/config/sbs.conf`.

| Key | Default | Meaning |
|---|---|---|
| `SBS_FAIL_ON_SEVERITY` | `HIGH` | `security-check.sh` exits 1 when a finding of this level or above exists. `NONE` never blocks. |
| `SBS_EXCLUDE_PATHS` | empty | space-separated paths excluded from detection, builtin checks and Semgrep |
| `SBS_SKIP_TOOLS` | empty | comma-separated tools never run locally |
| `SBS_COMPOSER_BIN` | empty | Composer command when it is not in `PATH`, e.g. `php /Applications/MAMP/bin/php/composer` (split on spaces, never evaluated) |
| `SBS_ADMIN_PATHS` | empty | space-separated admin paths checked for noindex by `check-headers.sh`, e.g. `/admin /login` |
| `SBS_SEMGREP_CONFIGS` | `p/owasp-top-ten` | extra Semgrep registry configs (network). Empty = local rules only |
| `SBS_ZAP_ALLOWED_HOSTS` | empty | non-local hosts you are authorised to scan with the ZAP baseline |
| `SBS_ZAP_TARGET` | empty | default `--zap-target` |
| `SBS_DEPENDABOT_INTERVAL` | `weekly` | used by `generate-dependabot.sh` |
| `SBS_DEPENDABOT_PR_LIMIT` | `5` | used by `generate-dependabot.sh` |
| `SBS_DEPENDABOT_COOLDOWN_DAYS` | `7` | days Dependabot waits before proposing a newly published version |
| `SBS_DETECT_DEPTH` | `5` | directory depth for stack detection |
| `SBS_FABRIC_PATTERNS_DIR` | `~/.config/fabric/patterns` | default destination of `install-fabric-patterns.sh` |

## Severity thresholds

Levels: `CRITICAL > HIGH > MEDIUM > LOW > INFO`. Mapping from tools:

| Tool | Mapping |
|---|---|
| Semgrep | `metadata.sbs-severity` if set, else `ERROR→HIGH`, `WARNING→MEDIUM`, `INFO→LOW` |
| SARIF (CodeQL, Snyk Code/IaC) | `security-severity` ≥9 CRITICAL, ≥7 HIGH, ≥4 MEDIUM, >0 LOW; else `error→HIGH`, `warning→MEDIUM`, `note→LOW` |
| Snyk Open Source | Snyk severity (critical/high/medium/low) |
| npm audit / composer audit | advisory severity (`moderate→MEDIUM`); composer advisories without severity → MEDIUM |
| ZAP | risk code 3 HIGH, 2 MEDIUM, 1 LOW, 0 INFO |

In GitHub Actions, set the repository variable `SBS_FAIL_ON_SEVERITY`; the *Security audit* workflow can also be
run manually with a `fail_on` input.

## Semgrep rules

Custom rules live in `config/semgrep/rules/*.yaml`, tests in `tests/semgrep/` (`ruleid:` / `ok:` annotations).
Add your own rules there and run:

```bash
semgrep --test --metrics=off --config config/semgrep/rules tests/semgrep
```

To silence one reviewed false positive, add `# nosemgrep: <rule-id>` with a comment explaining why.

## CodeQL

`config/codeql/codeql-config.yml` selects the `security-extended` suite and ignored paths. Languages are
detected (`detect-stack.sh --codeql-languages`): `actions`, `javascript-typescript`, `python`.

## ZAP

`config/zap/rules.tsv` sets `IGNORE`/`WARN`/`FAIL` per ZAP rule id. See [config/zap/README.md](../config/zap/README.md).

## Snyk

See [config/snyk/README.md](../config/snyk/README.md).
