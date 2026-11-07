// INTENTIONALLY VULNERABLE TEST FILE for saas-blind-security Semgrep rules. Never deploy.
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

app.get('/invoices/:id', async (req, res) => {
  // ruleid: sbs-js-sqli-template-literal
  const rows = await pool.query(`SELECT * FROM invoices WHERE id = ${req.params.id}`);
  // ruleid: sbs-js-sqli-template-literal
  await db.query("SELECT * FROM users WHERE email = '" + req.body.email + "'");
  // ok: sbs-js-sqli-template-literal
  await pool.query('SELECT * FROM invoices WHERE id = $1 AND tenant_id = $2', [req.params.id, req.user.tenantId]);

  // ruleid: sbs-js-nosql-injection-request-object
  const u = await User.findOne(req.body);
  // ok: sbs-js-nosql-injection-request-object
  const u2 = await User.findOne({ email: String(req.body.email) });

  // ruleid: sbs-js-express-reflected-xss
  res.send('<h1>Hello ' + req.query.name + '</h1>');

  // ruleid: sbs-js-idor-find-by-request-id
  const doc = await Document.findById(req.params.id);
  // ok: sbs-js-idor-find-by-request-id
  const doc2 = await Document.findOne({ _id: req.params.id, tenantId: req.user.tenantId });

  // ruleid: sbs-js-ssrf-request-url
  const r = await axios.get(req.query.url);

  // ruleid: sbs-js-path-traversal-sendfile
  res.sendFile(path.join(__dirname, 'uploads', req.params.name));

  // ruleid: sbs-js-command-injection
  child_process.exec('convert ' + req.body.file + ' out.png');
});

function auth(req, res, next) {
  // ruleid: sbs-js-jwt-decode-for-auth
  req.user = jwt.decode(req.headers.authorization);
  // ruleid: sbs-js-jwt-verify-without-algorithms
  const claims = jwt.verify(token, publicKey);
  // ok: sbs-js-jwt-verify-without-algorithms
  const claims2 = jwt.verify(token, publicKey, { algorithms: ['RS256'] });
  next();
}

// ruleid: sbs-js-cors-wildcard-credentials
app.use(cors({ origin: true, credentials: true }));
// ok: sbs-js-cors-wildcard-credentials
app.use(cors({ origin: ['https://app.example.com'], credentials: true }));

// ruleid: sbs-js-weak-random-token
const resetToken = Math.random().toString(36).slice(2);
// ok: sbs-js-weak-random-token
const resetToken2 = crypto.randomBytes(32).toString('hex');

// ruleid: sbs-js-weak-hash-password
const h = crypto.createHash('md5').update(password).digest('hex');

// ruleid: sbs-js-stripe-webhook-unverified
app.post('/webhooks/stripe', express.json(), (req, res) => {
  const event = req.body;
  handle(event);
  res.sendStatus(200);
});

// ok: sbs-js-stripe-webhook-unverified
app.post('/webhooks/stripe-safe', express.raw({ type: 'application/json' }), (req, res) => {
  const event = stripe.webhooks.constructEvent(req.body, req.headers['stripe-signature'], endpointSecret);
  handle(event);
  res.sendStatus(200);
});

function Comment({ html }) {
  // ruleid: sbs-js-dangerous-html-sink
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
function SafeComment({ html }) {
  // ok: sbs-js-dangerous-html-sink
  return <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />;
}
// ruleid: sbs-js-dangerous-html-sink
el.innerHTML = userBio;
// ok: sbs-js-dangerous-html-sink
el.innerHTML = '';
