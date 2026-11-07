# Fabric patterns for saas-blind-security

[Fabric](https://github.com/danielmiessler/Fabric) (MIT License, by Daniel Miessler) is an open-source
framework that runs reusable AI prompts called *patterns*. saas-blind-security ships **its own original
patterns** (prefixed `sbs_`) in Fabric's pattern format (`<name>/system.md`). No Fabric code or Fabric
pattern is copied into this repository; Fabric is an optional external tool you install yourself.

| Pattern | Use it on |
|---|---|
| `sbs_analyze_saas_architecture` | repository tree, manifests, routes, architecture notes |
| `sbs_audit_saas_security` | code + config excerpts for a structured audit |
| `sbs_find_code_vulnerabilities` | a source file or snippet |
| `sbs_analyze_codeql_results` | CodeQL SARIF / alert export |
| `sbs_interpret_semgrep_results` | Semgrep JSON/SARIF or `findings.json` |
| `sbs_interpret_snyk_report` | `snyk test --json` / Snyk SARIF |
| `sbs_analyze_zap_report` | ZAP `report_json.json` / Markdown report |
| `sbs_create_remediation_plan` | `findings.json` or a triaged finding list |
| `sbs_verify_security_fix` | the original finding + the diff of the fix |

## Install

1. Install Fabric by following its README, then run `fabric --setup` and configure an AI provider.
2. Recommended: in `fabric --setup`, set a **Custom Patterns** directory (e.g. `~/my-custom-patterns`) so Fabric
   updates never overwrite these patterns.
3. Copy the patterns:

```bash
./scripts/install-fabric-patterns.sh ~/my-custom-patterns
```

## Use

```bash
cat .sbs-results/<run>/raw/semgrep.json | fabric --pattern sbs_interpret_semgrep_results
cat .sbs-results/<run>/findings.json    | fabric --pattern sbs_create_remediation_plan
git diff main...fix/SBS-004             | fabric --pattern sbs_verify_security_fix
```

## Privacy

Fabric sends the input to the AI provider you configured. Scanner output can contain file paths, code and
sometimes data. Review what you send, prefer a provider and plan that match your data-handling policy, and
never pipe secrets or production data. Fabric's answers are a second opinion: verify them against the code.
