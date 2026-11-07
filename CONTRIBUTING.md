# Contributing to saas-blind-security

Thank you for helping make SaaS applications safer. This project is maintained by IbrahimCodeur.

## Ground rules

- Security over appearances: no feature that reports a check as done when it was not.
- No secrets — not even realistic fake ones — in commits. Generate credential-shaped test data at runtime.
- Intentionally vulnerable code lives only in `tests/fixtures/` and `tests/semgrep/`, clearly labelled.
- No third-party code or rules copied without a compatible licence and attribution.
- Do not add a new scanner unless it closes a documented coverage gap.

## Development setup

Requirements: bash, git, jq. For full checks: Python 3.10+ with `semgrep`, `yamllint`, `shellcheck-py`, and
[actionlint](https://github.com/rhysd/actionlint).

```bash
./tests/run-tests.sh
semgrep --test --metrics=off --config config/semgrep/rules tests/semgrep
shellcheck -x scripts/*.sh scripts/lib/*.sh tests/*.sh
actionlint
yamllint -c .yamllint.yml .
```

## Adding a Semgrep rule

1. Add the rule to the matching file in `config/semgrep/rules/` with `id: sbs-<lang>-<name>`, a clear `message`
   explaining the fix, and `metadata` (`cwe`, `owasp`, optional `sbs-severity`, `confidence`).
2. Add `# ruleid:` and `# ok:` cases to the file with the same base name in `tests/semgrep/`.
3. Run `semgrep --test`. Rules without tests are not merged.

## Adding a stack detection

Extend `scripts/detect-stack.sh`, add or extend a fixture in `tests/fixtures/`, and assert it in
`tests/run-tests.sh`. Update `docs/supported-technologies.md` honestly.

## Skills and Fabric patterns

Skills (`.claude/skills/<name>/SKILL.md`) need frontmatter `name` and `description` plus the sections
*Objectives*, *Steps*, *Security rules*, *Validation criteria*. Fabric patterns need *IDENTITY and PURPOSE*,
*STEPS*, *OUTPUT INSTRUCTIONS* and *INPUT*. The test suite enforces this.

## Scripts

- Compatible with bash 3.2 (macOS): no associative arrays, `mapfile`, or `${var,,}`.
- `set -uo pipefail`, quote everything, never `eval` input, never print secret values.
- Exit codes: 0 ok, 1 threshold/check failed, 2 usage or tool error.

## Workflows

- Top-level `permissions: contents: read`; elevate per job only.
- Pin actions to a full commit SHA with the version as a comment.
- Pass untrusted event data through `env:`.

## Pull requests

Small and focused, with tests and documentation updates, and a description of what you verified. By contributing
you agree that your contribution is licensed under the MIT License.
