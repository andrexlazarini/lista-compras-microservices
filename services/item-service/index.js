
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const jwt = require('jsonwebtoken');
const JsonDatabase = require('../../shared/JsonDatabase');
const registry = require('../../shared/serviceRegistry');

const PORT = process.env.PORT || 3003;
const JWT_SECRET = process.env.JWT_SECRET || 'supersecret';

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

const db = new JsonDatabase(path.resolve(__dirname, 'data', 'items.json'));

// simple auth (only for POST/PUT if needed)
function requireAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch (e) { return res.status(401).json({ error: 'Invalid token' }); }
}

// health
app.get('/health', (_req, res) => res.json({ status: 'UP', service: 'item-service' }));

// GET /items (filters: category, name)
app.get('/items', (req, res) => {
  const { category, name } = req.query;
  let all = db.all().filter(it => it.active);
  if (category) all = all.filter(it => it.category.toLowerCase() === String(category).toLowerCase());
  if (name) all = all.filter(it => it.name.toLowerCase().includes(String(name).toLowerCase()));
  res.json(all);
});

// GET /items/:id
app.get('/items/:id', (req, res) => {
  const it = db.findOne(x => x.id === req.params.id);
  if (!it) return res.status(404).json({ error: 'not found' });
  res.json(it);
});

// POST /items (auth)
app.post('/items', requireAuth, (req, res) => {
  const body = req.body || {};
  if (!body.name || !body.category) return res.status(400).json({ error: 'name and category required' });
  const now = new Date().toISOString();
  const id = 'itm-' + Math.random().toString(36).slice(2,8);
  const item = {
    id,
    name: body.name,
    category: body.category,
    brand: body.brand || '',
    unit: body.unit || 'un',
    averagePrice: Number(body.averagePrice || 0),
    barcode: body.barcode || '',
    description: body.description || '',
    active: body.active !== false,
    createdAt: now
  };
  db.upsert(item);
  res.status(201).json(item);
});

// PUT /items/:id
app.put('/items/:id', requireAuth, (req, res) => {
  const it = db.findOne(x => x.id === req.params.id);
  if (!it) return res.status(404).json({ error: 'not found' });
  const fields = ['name','category','brand','unit','averagePrice','barcode','description','active'];
  fields.forEach(f => { if (typeof req.body?.[f] !== 'undefined') it[f] = req.body[f]; });
  db.upsert(it);
  res.json(it);
});

// GET /categories
app.get('/categories', (_req, res) => {
  const cats = Array.from(new Set(db.all().map(x => x.category))).sort();
  res.json(cats);
});

// GET /search?q=...
app.get('/search', (req, res) => {
  const q = (req.query.q || '').toString().toLowerCase();
  if (!q) return res.json([]);
  const r = db.all().filter(x => (x.name.toLowerCase().includes(q) || x.brand.toLowerCase().includes(q)) && x.active);
  res.json(r);
});

app.listen(PORT, () => {
  const url = process.env.SVC_URL || `http://localhost:${PORT}`;
  registry.register({ name: 'item-service', url });
  console.log(`[item-service] listening on ${url}`);
});
