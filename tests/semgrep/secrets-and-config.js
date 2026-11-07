// INTENTIONALLY VULNERABLE TEST FILE for saas-blind-security Semgrep rules. Never deploy.
// ruleid: sbs-session-cookie-insecure
app.use(session({ secret: process.env.SESSION_SECRET, cookie: { secure: false } }));
// ok: sbs-session-cookie-insecure
app.use(session({ secret: process.env.SESSION_SECRET, cookie: { secure: true, httpOnly: true, sameSite: 'lax' } }));
const config = {
  // ruleid: sbs-hardcoded-credential-assignment
  jwtSecret: "s3cr3tValueForSigning",
  // ok: sbs-hardcoded-credential-assignment
  jwtSecretExample: "your-secret-here",
};
