# Changelog

All notable changes are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Author & Maintainer section (README in English and French), `AUTHORS.md` and `CITATION.cff` author metadata.

## [0.1.0] — 2026-11-07

### Added
- `security-check.sh` with default, `--report` and `--check-only` modes; severity gating; honest coverage tracking.
- Stack detection (PHP/Laravel, Node.js/Express/NestJS, Python/Django/FastAPI, React/Next.js/Vue/Nuxt/Angular,
  MySQL/MariaDB/PostgreSQL/MongoDB/Redis, Docker/GitHub Actions/Nginx/Apache, SaaS features).
- Dependency-free builtin checks (secrets, env files, debug flags, lockfiles, Docker, GitHub Actions).
- Result normaliser for Semgrep, Snyk, SARIF (CodeQL/Snyk Code/IaC), npm audit, composer audit, ZAP.
- Markdown report generator, severity gate, environment validator, HTTP header checker.
- 41 custom Semgrep rules for SaaS risks with unit tests.
- Workflows: CodeQL, Semgrep, Snyk, ZAP baseline, ZAP full scan (manual, guarded), Security audit with
  Dependency Review, Dependabot review helper, self-test CI.
- `install.sh`, `configure-github-security.sh`, `generate-dependabot.sh`, `install-fabric-patterns.sh`.
- `CLAUDE.md` and 12 Claude Code skills; 9 Fabric patterns; report, threat-model and remediation templates.
- Documentation in English, main documentation in French.

[0.1.0]: https://github.com/IbrahimCodeur/saas-blind-security/releases/tag/v0.1.0
