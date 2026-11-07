## What and why

## Verification

- [ ] `./tests/run-tests.sh`
- [ ] `semgrep --test --metrics=off --config config/semgrep/rules tests/semgrep` (if rules changed)
- [ ] `shellcheck -x scripts/*.sh scripts/lib/*.sh tests/*.sh`, `actionlint`, `yamllint -c .yamllint.yml .`
- [ ] Docs updated (including `docs/supported-technologies.md` if coverage changed)
- [ ] No secrets or credential-shaped strings added
