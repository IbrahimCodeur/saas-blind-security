# Contributing to saas-blind-security

Thank you for your interest in saas-blind-security. This guide explains how to contribute in a way that keeps
the project reliable, honest and safe to use.

## 1. About the project

saas-blind-security is an AI-assisted security framework that you install into a SaaS project. It combines:

- executable checks (`scripts/security-check.sh`): stack detection, builtin heuristics, Semgrep, Snyk,
  npm/composer audit, CodeQL and OWASP ZAP, normalised into one report with an honest coverage table;
- SaaS-specific Semgrep rules (`config/semgrep/rules/`) with unit tests (`tests/semgrep/`);
- GitHub workflows (`.github/workflows/`);
- instructions for AI coding agents (`CLAUDE.md`, `.claude/skills/`) and Fabric patterns (`fabric/`);
- templates and documentation (`templates/`, `docs/`).

Contributions of every size are welcome:

| Type | Examples |
|---|---|
| Bug fixes | a check that crashes, a false positive or false negative, a wrong exit code |
| Features | a new builtin check, a new option, a supported stack |
| Semgrep rules | a SaaS risk that the current rules miss |
| Scanner integrations | better parsing or normalisation of an existing tool's output |
| Tests | fixtures, regression tests, edge cases |
| Documentation | clearer guides, translations, corrections |
| Optimisations | faster scans, fewer dependencies, better portability |

Constructive feedback is a contribution too: a well-documented false positive report helps as much as code.

## 2. Contribution workflow

1. **Fork** the repository on GitHub.
2. **Clone** your fork:

   ```bash
   git clone https://github.com/<your-username>/saas-blind-security.git
   cd saas-blind-security
   ```

3. **Create a branch** for one change, named after its purpose:

   ```bash
   git checkout -b fix/lockfile-check      # or feat/…, docs/…, test/…
   ```

4. **Make your changes**, following the rules below.
5. **Run the checks** (see [Required checks](#required-checks)).
6. **Commit** with explicit messages. The project uses
   [Conventional Commits](https://www.conventionalcommits.org/): `fix(builtin): …`, `feat(semgrep): …`,
   `docs: …`, `test: …`. Explain *why* in the body when it is not obvious.
7. **Push** the branch to your fork: `git push -u origin fix/lockfile-check`.
8. **Open a Pull Request** against `main` of `IbrahimCodeur/saas-blind-security`.

### Required checks

Requirements: bash, git and jq. For the full set: Python 3.10+ with `semgrep`, `yamllint` and `shellcheck-py`,
plus [actionlint](https://github.com/rhysd/actionlint).

```bash
./tests/run-tests.sh
semgrep --test --metrics=off --config config/semgrep/rules tests/semgrep
shellcheck -x scripts/*.sh scripts/lib/*.sh tests/*.sh
actionlint
yamllint -c .yamllint.yml .
```

The CI workflow (`.github/workflows/ci.yml`) runs the same checks on Linux and macOS. Tests that need an
optional tool are reported as `SKIP`, never as `PASS`: say in your Pull Request which ones you could not run.

## 3. Development rules

- **Respect the existing structure.** Scripts live in `scripts/`, shared helpers in `scripts/lib/common.sh`,
  rules in `config/semgrep/rules/`, fixtures in `tests/fixtures/`. Follow the conventions of the file you edit.
- **Write clean, readable, maintainable code.** Small functions, clear names, comments that explain *why*.
- **Avoid unnecessary dependencies.** Scripts must keep working with only `git` and `jq`; any other tool is
  optional and detected at run time.
- **Never commit secrets** — no API keys, tokens, passwords or private keys, not even realistic fake ones.
  Tests generate credential-shaped strings at run time.
- **Never disable a security control to make a test pass** (authentication, validation, TLS verification,
  scanners, tests or CI checks), and never add `# nosemgrep`, `.snyk` ignores or ZAP `IGNORE` rules without a
  written justification accepted in review.
- **Add or update tests** with every behaviour change.
- **Document** new features and notable changes in `docs/`, the README when relevant, and `CHANGELOG.md`
  under *Unreleased*.

### Scripts

- Compatible with bash 3.2 (macOS): no associative arrays, `mapfile` or `${var,,}`.
- `set -uo pipefail`, quote every expansion, never `eval` input, never print secret values.
- Configuration is read with `sbs_load_config` (`SBS_*` keys only, never executed).
- Exit codes: `0` ok, `1` threshold or check failed, `2` usage or tool error.

### Semgrep rules

1. Add the rule to the matching file in `config/semgrep/rules/` with `id: sbs-<lang>-<name>`, a `message` that
   explains the fix, and `metadata` (`cwe`, `owasp`, and `confidence` when useful).
2. Add `ruleid:` and `ok:` cases to the file with the same base name in `tests/semgrep/`. The `ok:` cases must
   cover the safe forms developers really write, so the rule does not drown users in false positives.
3. Run `semgrep --test`. Rules without tests are not merged.

### Stack detection

Extend `scripts/detect-stack.sh`, add or extend a fixture in `tests/fixtures/`, assert it in
`tests/run-tests.sh`, and update `docs/supported-technologies.md` honestly.

### Skills and Fabric patterns

Skills (`.claude/skills/<name>/SKILL.md`) need frontmatter `name` and `description` and the sections
*Objectives*, *Steps*, *Security rules* and *Validation criteria*. Fabric patterns need *IDENTITY and PURPOSE*,
*STEPS*, *OUTPUT INSTRUCTIONS* and *INPUT*. The test suite enforces both.

### Workflows

- Top-level `permissions: contents: read`; elevate per job only.
- Pin actions to a full commit SHA with the version as a comment.
- Pass untrusted event data through `env:`, never directly inside `run:`.

## 4. Security requirements

saas-blind-security is a security project, so contributions are held to a higher bar:

- **Every new detection comes with tests** that prove it finds the issue (`ruleid:`, failing fixture) and stays
  quiet on safe code (`ok:`, clean fixture).
- **No contribution may weaken an existing protection**: guards on scan targets, secret redaction, workflow
  permissions, severity gates or honest coverage reporting.
- **Report vulnerabilities in the project responsibly**, privately, as described in [SECURITY.md](SECURITY.md).
- **Test only systems you are authorised to test.** Dynamic checks (`check-headers.sh`, ZAP) run against
  `localhost`, `*.test` or hosts you own; active scans never target production.
- **Avoid excessive false positives and wrong detections.** A check must say what it really verified; an alert
  nobody can act on erodes trust in every other alert.

## 5. Pull Requests

A Pull Request must:

- have an explicit title (Conventional Commits style is welcome);
- describe the problem solved or the feature added;
- explain the changes made and any trade-off;
- list the tests and checks you ran, and those you could not run;
- stay focused on one coherent goal — split unrelated changes into separate Pull Requests;
- pass the applicable CI checks.

The [Pull Request template](.github/pull_request_template.md) contains the verification checklist.
All contributions are reviewed and must be approved by the project maintainer before they are merged.

## 6. Issues

Open an issue from the [issue page](https://github.com/IbrahimCodeur/saas-blind-security/issues/new/choose)
and pick the matching template:

| You want to… | Template |
|---|---|
| report a bug | **Bug report** — version, area, what happened, steps to reproduce |
| report a compatibility problem (OS, bash version, stack, tool version) | **Bug report**, with the output of `scripts/validate-environment.sh` |
| report a wrong alert or a missed issue | **False positive / false negative** — rule id and a minimal code sample |
| propose a feature, rule or integration | **Feature request** — the coverage gap and references (OWASP, CWE, docs) |
| ask a technical question | **Question** |

Never include secrets, proprietary code or raw scanner output from a real application.

**Security vulnerabilities must never be reported in a public issue.** Use
[private vulnerability reporting](https://github.com/IbrahimCodeur/saas-blind-security/security/advisories/new)
as explained in [SECURITY.md](SECURITY.md).

## 7. License and project ownership

- The project is distributed under the [MIT License](LICENSE). By contributing, you agree that your
  contribution is licensed under the same terms.
- Contributors keep the rights they hold on their contributions, subject to that license.
- Contributors are credited as **contributors**, through the Git history and the
  [GitHub contributors page](https://github.com/IbrahimCodeur/saas-blind-security/graphs/contributors).
- The project's authorship must not be changed: no contribution may present anyone else as author, co-founder
  or original maintainer, or alter the author credits in `LICENSE`, `AUTHORS.md`, `CITATION.cff` or the READMEs.

**Author & Original Maintainer: IbrahimCodeur.**
IbrahimCodeur is the sole creator and initial maintainer of saas-blind-security.

## Code of Conduct

Everyone taking part in this project follows the [Code of Conduct](CODE_OF_CONDUCT.md).

---

Thank you for helping make SaaS applications safer.
