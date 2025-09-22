
// shared/JsonDatabase.js
// Mini "NoSQL" baseado em arquivo JSON simples.
// Cada instância representa uma coleção (um arquivo .json).

const fs = require('fs');
const path = require('path');

class JsonDatabase {
  constructor(filePath) {
    this.filePath = filePath;
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    if (!fs.existsSync(filePath)) {
      fs.writeFileSync(filePath, JSON.stringify({ data: [] }, null, 2));
    }
  }

  _read() {
    const raw = fs.readFileSync(this.filePath, 'utf-8') || '{"data":[]}';
    try { return JSON.parse(raw); } catch (e) { return { data: [] }; }
  }

  _write(obj) {
    fs.writeFileSync(this.filePath, JSON.stringify(obj, null, 2));
  }

  all() {
    return this._read().data;
  }

  saveAll(arr) {
    this._write({ data: arr });
  }

  findOne(predicate) {
    return this.all().find(predicate);
  }

  findMany(predicate) {
    return this.all().filter(predicate);
  }

  upsert(entity, idField = 'id') {
    const data = this.all();
    const idx = data.findIndex(x => x[idField] === entity[idField]);
    if (idx >= 0) data[idx] = entity; else data.push(entity);
    this.saveAll(data);
    return entity;
  }

  deleteById(id, idField = 'id') {
    const data = this.all().filter(x => x[idField] !== id);
    this.saveAll(data);
  }
}

module.exports = JsonDatabase;
