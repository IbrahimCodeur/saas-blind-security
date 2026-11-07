// INTENTIONALLY VULNERABLE FIXTURE. Never deploy.
const express = require('express');
const jwt = require('jsonwebtoken');
const app = express();

app.get('/api/invoices/:id', async (req, res) => {
  const rows = await pool.query(`SELECT * FROM invoices WHERE id = ${req.params.id}`);
  res.json(rows);
});

app.use((req, res, next) => {
  req.user = jwt.decode(req.headers.authorization);
  next();
});

app.post('/webhooks/stripe', express.json(), (req, res) => {
  const event = req.body;
  res.sendStatus(200);
});
