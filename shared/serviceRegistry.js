
// shared/serviceRegistry.js
// Registry simples baseado em arquivo com health-checks periódicos.

const fs = require('fs');
const path = require('path');
const axios = require('axios');

const REGISTRY_FILE = path.resolve(__dirname, 'registry.json');
const HEALTH_INTERVAL_MS = 30 * 1000; // 30s
const STALE_MS = 2 * 60 * 1000; // 2min

function now() { return new Date().toISOString(); }

function _load() {
  if (!fs.existsSync(REGISTRY_FILE)) {
    fs.writeFileSync(REGISTRY_FILE, JSON.stringify({ services: [] }, null, 2));
  }
  const raw = fs.readFileSync(REGISTRY_FILE, 'utf-8') || '{"services":[]}';
  try { return JSON.parse(raw) } catch (e) { return { services: [] } }
}

function _save(obj) {
  fs.writeFileSync(REGISTRY_FILE, JSON.stringify(obj, null, 2));
}

function list() {
  return _load().services;
}

function cleanup() {
  const reg = _load();
  const t = Date.now();
  reg.services = reg.services.filter(svc => (t - new Date(svc.lastHeartbeat).getTime()) < STALE_MS);
  _save(reg);
}

function register({ name, url }) {
  const reg = _load();
  const existingIdx = reg.services.findIndex(s => s.name === name && s.url === url);
  const entry = {
    name,
    url,
    status: 'UNKNOWN',
    lastHeartbeat: now()
  };
  if (existingIdx >= 0) {
    reg.services[existingIdx] = { ...reg.services[existingIdx], ...entry };
  } else {
    reg.services.push(entry);
  }
  _save(reg);

  // inicia heartbeats para este processo
  const timer = setInterval(async () => {
    try {
      cleanup();
      const { data } = await axios.get(`${url.replace(/\/+$/,'')}/health`).catch(() => ({ data: { status: 'DOWN' } }));
      update({ name, url, status: data?.status || 'DOWN' });
    } catch (e) {
      update({ name, url, status: 'DOWN' });
    }
  }, HEALTH_INTERVAL_MS);

  const stop = () => clearInterval(timer);
  process.on('exit', stop);
  process.on('SIGINT', () => { stop(); process.exit(0); });
  process.on('SIGTERM', () => { stop(); process.exit(0); });

  return { name, url };
}

function update({ name, url, status }) {
  const reg = _load();
  const idx = reg.services.findIndex(s => s.name === name && s.url === url);
  if (idx >= 0) {
    reg.services[idx].status = status || reg.services[idx].status;
    reg.services[idx].lastHeartbeat = now();
    _save(reg);
  }
}

function resolve(name) {
  // retorna a primeira entrada UP do serviço
  cleanup();
  const svc = list().find(s => s.name === name && s.status === 'UP');
  if (!svc) throw new Error(`Service ${name} not available`);
  return svc.url.replace(/\/+$/,'');
}

module.exports = { register, resolve, list, cleanup, REGISTRY_FILE };
