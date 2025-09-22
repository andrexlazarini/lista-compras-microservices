
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const axios = require('axios');
const { v4: uuid } = require('uuid');
const jwt = require('jsonwebtoken');
const JsonDatabase = require('../../shared/JsonDatabase');
const registry = require('../../shared/serviceRegistry');

const PORT = process.env.PORT || 3002;
const JWT_SECRET = process.env.JWT_SECRET || 'supersecret';

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

const db = new JsonDatabase(path.resolve(__dirname, 'data', 'lists.json'));

// auth
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
app.get('/health', (_req, res) => res.json({ status: 'UP', service: 'list-service' }));

function recalcSummary(list) {
  const totalItems = list.items.length;
  const purchasedItems = list.items.filter(i => i.purchased).length;
  const estimatedTotal = list.items.reduce((acc, i) => acc + Number(i.estimatedPrice || 0) * Number(i.quantity || 0), 0);
  list.summary = { totalItems, purchasedItems, estimatedTotal: Number(estimatedTotal.toFixed(2)) };
  return list;
}

// POST /lists
app.post('/lists', requireAuth, (req, res) => {
  const now = new Date().toISOString();
  const list = {
    id: uuid(),
    userId: req.user.id,
    name: req.body?.name || 'Nova lista',
    description: req.body?.description || '',
    status: 'active',
    items: [],
    summary: { totalItems: 0, purchasedItems: 0, estimatedTotal: 0 },
    createdAt: now, updatedAt: now
  };
  db.upsert(list);
  res.status(201).json(list);
});

// GET /lists (do usuário)
app.get('/lists', requireAuth, (req, res) => {
  const lists = db.findMany(l => l.userId === req.user.id);
  res.json(lists);
});

// GET /lists/:id
app.get('/lists/:id', requireAuth, (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  res.json(list);
});

// PUT /lists/:id
app.put('/lists/:id', requireAuth, (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  const fields = ['name','description','status'];
  fields.forEach(f => { if (typeof req.body?.[f] !== 'undefined') list[f] = req.body[f]; });
  list.updatedAt = new Date().toISOString();
  recalcSummary(list);
  db.upsert(list);
  res.json(list);
});

// DELETE /lists/:id
app.delete('/lists/:id', requireAuth, (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  db.deleteById(list.id);
  res.json({ ok: true });
});

// POST /lists/:id/items (adicionar item)
app.post('/lists/:id/items', requireAuth, async (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  const { itemId, quantity = 1, estimatedPrice, notes = '' } = req.body || {};
  if (!itemId) return res.status(400).json({ error: 'itemId required' });

  // busca no item-service
  let itemSvcUrl;
  try {
    itemSvcUrl = registry.resolve('item-service');
  } catch (e) { return res.status(503).json({ error: 'item-service unavailable' }); }

  let itemData;
  try {
    const { data } = await axios.get(`${itemSvcUrl}/items/${itemId}`);
    itemData = data;
  } catch (e) {
    return res.status(404).json({ error: 'item not found in catalog' });
  }

  const entry = {
    itemId: itemData.id,
    itemName: itemData.name,
    quantity: Number(quantity),
    unit: itemData.unit || 'un',
    estimatedPrice: Number(typeof estimatedPrice !== 'undefined' ? estimatedPrice : itemData.averagePrice || 0),
    purchased: false,
    notes,
    addedAt: new Date().toISOString()
  };
  list.items.push(entry);
  list.updatedAt = new Date().toISOString();
  recalcSummary(list);
  db.upsert(list);
  res.status(201).json(list);
});

// PUT /lists/:id/items/:itemId
app.put('/lists/:id/items/:itemId', requireAuth, (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  const it = list.items.find(i => i.itemId === req.params.itemId);
  if (!it) return res.status(404).json({ error: 'item not found in list' });
  const fields = ['quantity','estimatedPrice','purchased','notes'];
  fields.forEach(f => { if (typeof req.body?.[f] !== 'undefined') it[f] = req.body[f]; });
  list.updatedAt = new Date().toISOString();
  recalcSummary(list);
  db.upsert(list);
  res.json(list);
});

// DELETE /lists/:id/items/:itemId
app.delete('/lists/:id/items/:itemId', requireAuth, (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  list.items = list.items.filter(i => i.itemId !== req.params.itemId);
  list.updatedAt = new Date().toISOString();
  recalcSummary(list);
  db.upsert(list);
  res.json(list);
});

// GET /lists/:id/summary
app.get('/lists/:id/summary', requireAuth, (req, res) => {
  const list = db.findOne(l => l.id === req.params.id);
  if (!list || list.userId !== req.user.id) return res.status(404).json({ error: 'not found' });
  recalcSummary(list);
  db.upsert(list);
  res.json(list.summary);
});

// extra search endpoint for aggregates
app.get('/lists/search', requireAuth, (req, res) => {
  const q = (req.query.q || '').toString().toLowerCase();
  const mine = db.findMany(l => l.userId === req.user.id);
  if (!q) return res.json(mine);
  const r = mine.filter(l => l.name.toLowerCase().includes(q) || l.description.toLowerCase().includes(q));
  res.json(r);
});

app.listen(PORT, () => {
  const url = process.env.SVC_URL || `http://localhost:${PORT}`;
  registry.register({ name: 'list-service', url });
  console.log(`[list-service] listening on ${url}`);
});
