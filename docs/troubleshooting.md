# Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `jq is required` | jq missing | install jq (`brew install jq`, `apt-get install jq`) |
| `semgrep: missing` in the plan | Semgrep not installed | `pipx install semgrep`; the check is reported as *not run*, never as passed |
| Semgrep `error`, then "local SaaS rules only" | no network for registry rules | expected offline; or set `SBS_SEMGREP_CONFIGS=` |
| Snyk `skipped: no SNYK_TOKEN` | token not set | `export SNYK_TOKEN=…` or `snyk auth`; GitHub: add the secret |
| Snyk workflow skipped on a fork PR | GitHub does not pass secrets to fork PRs | expected; it runs after merge on `main` |
| `snyk-code skipped (exit 2)` | Snyk Code not enabled for your org | enable it in Snyk settings, or ignore |
| Snyk Python finds nothing | dependencies not installed | `pip install -r requirements.txt` before scanning |
| CodeQL job not running | no supported language detected (e.g. pure PHP) | expected; Semgrep/Snyk cover PHP |
| CodeQL "default setup" conflict | default setup enabled in settings | disable it; `codeql.yml` is an advanced setup |
| SARIF upload fails on fork PRs | no `security-events: write` for forks | upload is skipped for forks by design |
| ZAP `refused` | host not local and not in `SBS_ZAP_ALLOWED_HOSTS` | add the host **only** if you are authorised to scan it |
| ZAP cannot reach `localhost` from Docker | container network isolation | macOS/Windows: `http://host.docker.internal:<port>`; Linux: run the app on an address reachable from the container |
| ZAP full scan refused | confirmation phrase, allow-list or production list | read the guard message; never bypass it |
| Dependabot "dependency_file_not_found" | ecosystem listed without manifest | regenerate with `scripts/generate-dependabot.sh` |
| `configure-github-security.sh` step "failed" | missing admin rights or feature not in your plan | check the message; private repos may need GitHub Advanced Security |
| Cannot merge your own PR after the ruleset | `--reviews 1` on a single-maintainer repo | re-run with `--reviews 0` |
| Exit code 2 | usage error or a scanner failed | read `raw/<tool>.log` in the results directory |
| Many false positives | pattern rules lack context | triage, then improve the rule (with tests) or add a justified `nosemgrep` |
