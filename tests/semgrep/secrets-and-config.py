# INTENTIONALLY VULNERABLE TEST FILE for saas-blind-security Semgrep rules. Never deploy.
# ruleid: sbs-hardcoded-credential-assignment
STRIPE_WEBHOOK_SECRET = "Zq8fK2mLp0RtVw9x"
# ok: sbs-hardcoded-credential-assignment
STRIPE_WEBHOOK_SECRET_PLACEHOLDER = "changeme"
# ok: sbs-hardcoded-credential-assignment
API_KEY = os.environ["API_KEY"]
