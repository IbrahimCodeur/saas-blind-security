# OWASP ZAP configuration

* `rules.tsv` — per-rule action (`IGNORE`, `WARN`, `FAIL`) used by the baseline and full-scan workflows
  (`rules_file_name` input of the official ZAP actions) and by `zap-baseline.py -c` locally.
* **Baseline scan** = spider + *passive* rules only. It does not send attack payloads. Still: only scan
  systems you own or are authorised to test.
* **Full scan** = *active* attacks (injection payloads). Run it **only** against a disposable test or
  staging environment, never production, and only with written authorisation. The `zap-full-scan.yml`
  workflow is manual-only and refuses hosts that are not in `SBS_ZAP_ALLOWED_HOSTS` or that are listed in
  `SBS_ZAP_PRODUCTION_HOSTS`.

Authenticated scanning (logged-in areas) needs a ZAP context / Automation Framework plan; see
https://www.zaproxy.org/docs/automate/automation-framework/ . It is not configured by default.
