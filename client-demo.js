
// client-demo.js
const axios = require('axios');
const base = 'http://localhost:3000/api';

(async () => {
  try {
    const rand = Math.floor(Math.random() * 100000);
    const email = `user${rand}@demo.com`;
    const password = 'secret123';

    console.log('# Registering user...');
    await axios.post(`${base}/auth/register`, {
      email, username: `user${rand}`, password, firstName: 'User', lastName: `${rand}`
    }).then(r => console.log('Registered:', r.data)).catch(e => console.log('Register maybe exists:', e.response?.data || e.message));

    console.log('# Logging in...');
    const login = await axios.post(`${base}/auth/login`, { email, password });
    const token = login.data.token;
    const userId = login.data.user.id;
    console.log('Token:', token.slice(0,20)+'...');

    console.log('# Search items...');
    const items = await axios.get(`${base}/items/search`, { params: { q: 'arroz' }, headers: { Authorization: `Bearer ${token}` } });
    console.log('Found items:', items.data.map(i => i.name));

    console.log('# Create list...');
    const list = await axios.post(`${base}/lists`, { name: 'Compra da semana', description: 'Feira e limpeza' }, { headers: { Authorization: `Bearer ${token}` } });
    console.log('List created:', list.data.id);

    const itemCat = await axios.get(`${base}/items`, { params: { category: 'Alimentos' }, headers: { Authorization: `Bearer ${token}` } });
    const first = itemCat.data[0];
    console.log('# Add item to list...', first?.name);
    await axios.post(`${base}/lists/${list.data.id}/items`, { itemId: first.id, quantity: 2 }, { headers: { Authorization: `Bearer ${token}` } });

    console.log('# Dashboard...');
    const dashboard = await axios.get(`${base}/dashboard`, { headers: { Authorization: `Bearer ${token}` } });
    console.log('Dashboard:', dashboard.data);

    console.log('# Health:', (await axios.get('http://localhost:3000/health')).data);
    console.log('# Registry:', (await axios.get('http://localhost:3000/registry')).data);
  } catch (e) {
    console.error('DEMO ERROR', e.response?.data || e.message);
  }
})();
