# Security Policy

saas-blind-security is a security tool, so vulnerabilities in it matter (for example: a script that leaks
secrets into logs, a workflow with excessive permissions, a guard that lets an active scan hit an
unauthorised host, a rule that silently misses an issue class it claims to cover).

## Supported versions

| Version | Supported |
|---|---|
| 0.1.x | ✅ |

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private reporting:
[Report a vulnerability](https://github.com/IbrahimCodeur/saas-blind-security/security/advisories/new)
(*Security → Advisories → Report a vulnerability*).

Please include: affected file/workflow, version or commit, impact, reproduction steps, and a suggested fix if
you have one. Never include real secrets or third-party data.

What to expect (best effort, single maintainer): acknowledgement within 7 days, an assessment within 14 days,
and a fix or mitigation plan for confirmed issues. You will be credited in the advisory unless you prefer not to be.

## Scope

In scope: everything in this repository. Out of scope: vulnerabilities in third-party tools (CodeQL, Semgrep,
Snyk, ZAP, Fabric, GitHub) — report those to their maintainers; findings produced *by* the framework in your own
application — those belong to your project.

## Safe use

- Only scan systems you own or are explicitly authorised to test.
- Keep `.sbs-results/` out of version control and do not publish raw scanner output.

Maintained by IbrahimCodeur.
