# INTENTIONALLY VULNERABLE FIXTURE. Never deploy.
import jwt
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True)


@app.get("/tenants/{tenant_id}/invoices")
def invoices(tenant_id: str, cursor=None, token: str = ""):
    claims = jwt.decode(token, options={"verify_signature": False})
    cursor.execute(f"SELECT * FROM invoices WHERE tenant_id = {tenant_id}")
    return cursor.fetchall()
