
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
const { v4: uuid } = require('uuid');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const JsonDatabase = require('../../shared/JsonDatabase');
const registry = require('../../shared/serviceRegistry');

const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'supersecret';

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

const db = new JsonDatabase(path.resolve(__dirname, 'data', 'users.json'));

// auth middleware (local)
function requireAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// health
app.get('/health', (_req, res) => res.json({ status: 'UP', service: 'user-service' }));

// register
app.post('/auth/register', async (req, res) => {
  const { email, username, password, firstName = '', lastName = '' } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
  const exists = db.findOne(u => u.email === email);
  if (exists) return res.status(409).json({ error: 'email already in use' });
  const id = uuid();
  const now = new Date().toISOString();
  const user = {
    id,
    email,
    username: username || email.split('@')[0],
    password: bcrypt.hashSync(password, 10),
    firstName, lastName,
    preferences: { defaultStore: '', currency: 'BRL' },
    createdAt: now, updatedAt: now
  };
  db.upsert(user);
  const safe = { ...user }; delete safe.password;
  return res.status(201).json(safe);
});

// login (email or username)
app.post('/auth/login', async (req, res) => {
  const { email, username, password } = req.body || {};
  if ((!email && !username) || !password) return res.status(400).json({ error: 'credentials required' });
  const user = db.findOne(u => (email ? u.email === email : u.username === username));
  if (!user) return res.status(401).json({ error: 'invalid credentials' });
  const ok = bcrypt.compareSync(password, user.password);
  if (!ok) return res.status(401).json({ error: 'invalid credentials' });
  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '2h' });
  const safe = { ...user }; delete safe.password;
  res.json({ token, user: safe });
});

// get user
app.get('/users/:id', requireAuth, (req, res) => {
  if (req.params.id !== req.user.id) return res.status(403).json({ error: 'forbidden' });
  const user = db.findOne(u => u.id === req.params.id);
  if (!user) return res.status(404).json({ error: 'not found' });
  const safe = { ...user }; delete safe.password;
  res.json(safe);
});

// update user
app.put('/users/:id', requireAuth, (req, res) => {
  if (req.params.id !== req.user.id) return res.status(403).json({ error: 'forbidden' });
  const user = db.findOne(u => u.id === req.params.id);
  if (!user) return res.status(404).json({ error: 'not found' });
  const fields = ['firstName', 'lastName', 'preferences'];
  fields.forEach(f => { if (typeof req.body?.[f] !== 'undefined') user[f] = req.body[f]; });
  if (req.body?.password) user.password = bcrypt.hashSync(req.body.password, 10);
  user.updatedAt = new Date().toISOString();
  db.upsert(user);
  const safe = { ...user }; delete safe.password;
  res.json(safe);
});

app.listen(PORT, () => {
  const url = process.env.SVC_URL || `http://localhost:${PORT}`;
  registry.register({ name: 'user-service', url });
  console.log(`[user-service] listening on ${url}`);
});
