# INTENTIONALLY VULNERABLE TEST FILE for saas-blind-security Semgrep rules. Never deploy.
import hashlib
import pickle
import random
import secrets

import jwt
import requests
import yaml


def view(request, cursor, user_id):
    # ruleid: sbs-py-sqli-string-formatting
    cursor.execute(f"SELECT * FROM invoices WHERE id = {user_id}")
    # ruleid: sbs-py-sqli-string-formatting
    cursor.execute("SELECT * FROM users WHERE email = '%s'" % request.GET.get("email"))
    # ok: sbs-py-sqli-string-formatting
    cursor.execute("SELECT * FROM invoices WHERE id = %s", [user_id])

    # ruleid: sbs-py-insecure-deserialization
    data = pickle.loads(request.body)
    # ruleid: sbs-py-insecure-deserialization
    conf = yaml.load(request.body)
    # ok: sbs-py-insecure-deserialization
    conf = yaml.load(request.body, Loader=yaml.SafeLoader)

    # ruleid: sbs-py-jwt-verification-disabled
    claims = jwt.decode(token, options={"verify_signature": False})
    # ok: sbs-py-jwt-verification-disabled
    claims = jwt.decode(token, key, algorithms=["RS256"])

    # ruleid: sbs-py-ssrf-request-url
    r = requests.get(request.GET.get("url"))

    # ruleid: sbs-py-weak-password-hash
    h = hashlib.md5(password.encode())

    # ruleid: sbs-py-weak-random-token
    reset_token = random.randint(100000, 999999)
    # ok: sbs-py-weak-random-token
    reset_token = secrets.token_urlsafe(32)

    # ruleid: sbs-py-path-traversal-open
    f = open("/srv/uploads/" + request.GET.get("name"))

    # ruleid: sbs-py-django-mark-safe-variable
    html = mark_safe(user_bio)
    # ok: sbs-py-django-mark-safe-variable
    html = mark_safe("<b>static</b>")


# ruleid: sbs-py-csrf-exempt
@csrf_exempt
def billing_hook(request):
    return None


# ruleid: sbs-py-fastapi-cors-wildcard-credentials
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True)
