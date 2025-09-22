// api-gateway/index.js
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const axios = require('axios');
const jwt = require('jsonwebtoken');

// Shared registry (arquivo)
const registry = require('../shared/serviceRegistry'); // { register?, resolve, list, cleanup, update }

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'supersecret';

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('combined'));

// ------------------------- Circuit Breaker -------------------------
const breaker = {
  state: {},           // name -> { fails, openUntil }
  threshold: 3,        // nº de falhas consecutivas para abrir
  cooldownMs: 60_000,  // tempo de circuito aberto
};

function canCall(service) {
  const st = breaker.state[service];
  if (!st) return true;
  if (st.openUntil && Date.now() < st.openUntil) return false; // OPEN
  return true; // CLOSED / HALF-OPEN
}
function onSuccess(service) {
  breaker.state[service] = { fails: 0, openUntil: 0 };
}
function onFailure(service) {
  const st = breaker.state[service] || { fails: 0, openUntil: 0 };
  st.fails += 1;
  if (st.fails >= breaker.threshold) {
    st.openUntil = Date.now() + breaker.cooldownMs;
  }
  breaker.state[service] = st;
}

// ---------------------------- Auth helper --------------------------
function requireAuth(req, res, next) {
  const h = req.headers.authorization || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing token' });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

// ----------------------------- Proxy helper ------------------------
async function proxy(serviceName, method, path, req, res) {
  if (!canCall(serviceName)) {
    return res.status(503).json({ error: `Circuit open for ${serviceName}` });
  }

  let base;
  try {
    base = registry.resolve(serviceName); // ex: http://localhost:3003
  } catch (e) {
    onFailure(serviceName);
    return res.status(503).json({ error: `${serviceName} unavailable` });
  }

  try {
    const url = base + path;
    const opt = {
      method,
      url,
      params: req.query,
      data: req.body,
      headers: {}
    };
    if (req.headers.authorization) opt.headers['Authorization'] = req.headers.authorization;

    const { data, status } = await axios(opt);
    onSuccess(serviceName);
    res.status(status).json(data);
  } catch (e) {
    onFailure(serviceName);
    res.status(e.response?.status || 500).json(e.response?.data || { error: e.message });
  }
}

// ------------------------ Health Poll Ativo ------------------------
// O gateway verifica periodicamente os serviços e atualiza o registry.
// Assim, se um serviço cair, o status muda para DOWN em ~30s.
const EXPECTED_SERVICES = ['user-service', 'item-service', 'list-service'];
const HEALTH_PERIOD_MS = 30_000;

setInterval(async () => {
  try {
    const entries = registry.list().filter(s => EXPECTED_SERVICES.includes(s.name));
    await Promise.all(entries.map(async (svc) => {
      const base = svc.url.replace(/\/+$/, '');
      try {
        await axios.get(`${base}/health`, { timeout: 2500 });
        registry.update({ name: svc.name, url: svc.url, status: 'UP' });
      } catch {
        registry.update({ name: svc.name, url: svc.url, status: 'DOWN' });
      }
    }));
    registry.cleanup();
  } catch {
    /* silencioso */
  }
}, HEALTH_PERIOD_MS);

// ------------------------------ Routes -----------------------------

// AUTH & USERS  → user-service
app.post('/api/auth/register', (req, res) =>
  proxy('user-service', 'post', '/auth/register', req, res)
);
app.post('/api/auth/login', (req, res) =>
  proxy('user-service', 'post', '/auth/login', req, res)
);
app.get('/api/users/:id', requireAuth, (req, res) =>
  proxy('user-service', 'get', `/users/${req.params.id}`, req, res)
);
app.put('/api/users/:id', requireAuth, (req, res) =>
  proxy('user-service', 'put', `/users/${req.params.id}`, req, res)
);

// ITEMS → item-service
app.get('/api/items', (req, res) =>
  proxy('item-service', 'get', '/items', req, res)
);
app.get('/api/items/search', (req, res) =>
  proxy('item-service', 'get', '/search', req, res)
);
app.get('/api/items/categories', (req, res) =>
  proxy('item-service', 'get', '/categories', req, res)
);
app.get('/api/items/:id', (req, res) =>
  proxy('item-service', 'get', `/items/${req.params.id}`, req, res)
);
app.post('/api/items', requireAuth, (req, res) =>
  proxy('item-service', 'post', '/items', req, res)
);
app.put('/api/items/:id', requireAuth, (req, res) =>
  proxy('item-service', 'put', `/items/${req.params.id}`, req, res)
);

// LISTS → list-service
app.post('/api/lists', requireAuth, (req, res) =>
  proxy('list-service', 'post', '/lists', req, res)
);
app.get('/api/lists', requireAuth, (req, res) =>
  proxy('list-service', 'get', '/lists', req, res)
);
app.get('/api/lists/:id', requireAuth, (req, res) =>
  proxy('list-service', 'get', `/lists/${req.params.id}`, req, res)
);
app.put('/api/lists/:id', requireAuth, (req, res) =>
  proxy('list-service', 'put', `/lists/${req.params.id}`, req, res)
);
app.delete('/api/lists/:id', requireAuth, (req, res) =>
  proxy('list-service', 'delete', `/lists/${req.params.id}`, req, res)
);
app.post('/api/lists/:id/items', requireAuth, (req, res) =>
  proxy('list-service', 'post', `/lists/${req.params.id}/items`, req, res)
);
app.put('/api/lists/:id/items/:itemId', requireAuth, (req, res) =>
  proxy('list-service', 'put', `/lists/${req.params.id}/items/${req.params.itemId}`, req, res)
);
app.delete('/api/lists/:id/items/:itemId', requireAuth, (req, res) =>
  proxy('list-service', 'delete', `/lists/${req.params.id}/items/${req.params.itemId}`, req, res)
);
app.get('/api/lists/:id/summary', requireAuth, (req, res) =>
  proxy('list-service', 'get', `/lists/${req.params.id}/summary`, req, res)
);

// ---------------------------- Agregados ----------------------------
app.get('/api/search', requireAuth, async (req, res) => {
  try {
    const [itemsBase, listsBase] = [
      registry.resolve('item-service'),
      registry.resolve('list-service')
    ];
    const [items, lists] = await Promise.all([
      axios.get(`${itemsBase.replace(/\/+$/,'')}/search`, { params: { q: req.query.q || '' } }),
      axios.get(`${listsBase.replace(/\/+$/,'')}/lists/search`, {
        params: { q: req.query.q || '' },
        headers: { Authorization: req.headers.authorization || '' }
      })
    ]);
    res.json({ q: req.query.q || '', items: items.data, lists: lists.data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/api/dashboard', requireAuth, async (req, res) => {
  try {
    const [itemsBase, listsBase] = [
      registry.resolve('item-service'),
      registry.resolve('list-service')
    ];
    const [cats, lists] = await Promise.all([
      axios.get(`${itemsBase.replace(/\/+$/,'')}/categories`),
      axios.get(`${listsBase.replace(/\/+$/,'')}/lists`, { headers: { Authorization: req.headers.authorization || '' } })
    ]);
    const myLists = lists.data || [];
    const totals = {
      totalLists: myLists.length,
      totalItemsInLists: myLists.reduce((acc, l) => acc + (l.items?.length || 0), 0),
      purchasedItems: myLists.reduce((acc, l) => acc + (l.items?.filter(i => i.purchased).length || 0), 0),
      estimatedGrandTotal: Number(myLists.reduce((acc, l) => acc + (l.summary?.estimatedTotal || 0), 0).toFixed(2)),
      categoriesAvailable: cats.data
    };
    res.json(totals);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// -------------------- Health & Registry do Gateway -----------------
app.get('/health', async (_req, res) => {
  try {
    // faz uma rodada de verificação rápida
    const entries = registry.list();
    await Promise.all(entries.map(async (svc) => {
      try {
        await axios.get(`${svc.url.replace(/\/+$/,'')}/health`, { timeout: 1500 });
        registry.update({ name: svc.name, url: svc.url, status: 'UP' });
      } catch {
        registry.update({ name: svc.name, url: svc.url, status: 'DOWN' });
      }
    }));
    registry.cleanup();
    res.json({ gateway: 'UP', services: registry.list(), breaker });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

app.get('/registry', (_req, res) => {
  try {
    res.json({ services: registry.list() });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// raiz do gateway
app.get('/', (_req, res) => res.json({ name: 'api-gateway', status: 'UP' }));

app.listen(PORT, () => {
  console.log(`[api-gateway] listening on http://localhost:${PORT}`);
});
