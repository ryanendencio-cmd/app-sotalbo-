/**
 * MySQL Adapter mimicking Firestore API
 * Allows complete zero-breaking transition from Firestore to MySQL.
 */

const mysql = require('mysql2/promise');
const crypto = require('crypto');

const pool = mysql.createPool({
  host: process.env.MYSQL_HOST || 'localhost',
  user: process.env.MYSQL_USER || 'root',
  password: process.env.MYSQL_PASSWORD || 'root',
  database: process.env.MYSQL_DATABASE || 'buildtrack_db',
  waitForConnections: true,
  connectionLimit: 20,
  queueLimit: 0,
  charset: 'utf8mb4'
});

// Cache table columns to automatically handle missing/extra fields gracefully
const tableColumnsCache = {};

async function getTableColumns(tableName) {
  if (tableColumnsCache[tableName]) return tableColumnsCache[tableName];
  try {
    const [cols] = await pool.query(`DESCRIBE \`${tableName}\``);
    tableColumnsCache[tableName] = cols.map(c => c.Field);
    return tableColumnsCache[tableName];
  } catch (err) {
    return null;
  }
}

// Auto-add column if dynamic document has a new property not yet in table
async function ensureColumnsExist(tableName, data) {
  const existingCols = await getTableColumns(tableName);
  if (!existingCols) return;

  for (const key of Object.keys(data)) {
    if (key === 'firestore_id' || key === 'id') continue;
    if (!existingCols.includes(key)) {
      try {
        await pool.query(`ALTER TABLE \`${tableName}\` ADD COLUMN \`${key}\` LONGTEXT NULL`);
        existingCols.push(key);
      } catch (_) {}
    }
  }
}

function generateDocId() {
  return crypto.randomBytes(10).toString('hex');
}

function parseRowData(row) {
  if (!row) return null;
  const copy = { ...row };
  const docId = copy.firestore_id || copy.id;
  if (!copy.id) copy.id = docId;

  // Try parse any JSON strings in columns
  for (const [k, v] of Object.entries(copy)) {
    if (typeof v === 'string' && (v.startsWith('{') || v.startsWith('['))) {
      try {
        copy[k] = JSON.parse(v);
      } catch (_) {}
    }
  }
  return copy;
}

class DocumentSnapshot {
  constructor(row, requestedId) {
    this._row = row ? parseRowData(row) : null;
    this.id = this._row ? (this._row.firestore_id || this._row.id || requestedId) : requestedId;
    this.exists = Boolean(this._row);
  }

  data() {
    return this._row ? { ...this._row } : undefined;
  }
}

class QuerySnapshot {
  constructor(rows) {
    this.docs = rows.map(r => new DocumentSnapshot(r));
    this.size = this.docs.length;
    this.empty = this.docs.length === 0;
  }

  forEach(callback) {
    this.docs.forEach(callback);
  }
}

class DocumentReference {
  constructor(colName, docId) {
    this.colName = colName;
    this.id = docId || generateDocId();
  }

  async get() {
    const [rows] = await pool.query(
      `SELECT * FROM \`${this.colName}\` WHERE \`firestore_id\` = ? OR \`id\` = ? LIMIT 1`,
      [this.id, this.id]
    );
    return new DocumentSnapshot(rows[0], this.id);
  }

  async set(data, options = {}) {
    await ensureColumnsExist(this.colName, data);
    const existingCols = await getTableColumns(this.colName);
    const idKey = existingCols.includes('firestore_id') ? 'firestore_id' : 'id';
    
    const docData = { ...data, [idKey]: this.id };
    const fields = Object.keys(docData).filter(k => existingCols.includes(k));
    
    const columns = fields.map(f => `\`${f}\``).join(', ');
    const placeholders = fields.map(() => '?').join(', ');
    const updateClauses = fields
      .filter(f => f !== idKey)
      .map(f => `\`${f}\` = VALUES(\`${f}\`)`)
      .join(', ');

    const values = fields.map(f => {
      const v = docData[f];
      return (typeof v === 'object' && v !== null) ? JSON.stringify(v) : v;
    });

    const sql = `
      INSERT INTO \`${this.colName}\` (${columns}) 
      VALUES (${placeholders}) 
      ON DUPLICATE KEY UPDATE ${updateClauses || `${idKey} = VALUES(${idKey})`}
    `;

    await pool.query(sql, values);
    return this;
  }

  async update(data) {
    await ensureColumnsExist(this.colName, data);
    const existingCols = await getTableColumns(this.colName);
    const fields = Object.keys(data).filter(k => existingCols.includes(k));

    if (fields.length === 0) return this;

    const setClauses = fields.map(f => `\`${f}\` = ?`).join(', ');
    const values = fields.map(f => {
      const v = data[f];
      return (typeof v === 'object' && v !== null) ? JSON.stringify(v) : v;
    });

    values.push(this.id, this.id);

    await pool.query(
      `UPDATE \`${this.colName}\` SET ${setClauses} WHERE \`firestore_id\` = ? OR \`id\` = ?`,
      values
    );
    return this;
  }

  async delete() {
    await pool.query(
      `DELETE FROM \`${this.colName}\` WHERE \`firestore_id\` = ? OR \`id\` = ?`,
      [this.id, this.id]
    );
    return true;
  }
}

class Query {
  constructor(colName) {
    this.colName = colName;
    this._wheres = [];
    this._orderBys = [];
    this._limit = null;
  }

  where(field, op, val) {
    this._wheres.push({ field, op, val });
    return this;
  }

  orderBy(field, direction = 'asc') {
    this._orderBys.push({ field, direction: direction.toLowerCase() });
    return this;
  }

  limit(num) {
    this._limit = num;
    return this;
  }

  async get() {
    const existingCols = await getTableColumns(this.colName);
    if (!existingCols) {
      return new QuerySnapshot([]);
    }

    let sql = `SELECT * FROM \`${this.colName}\``;
    const params = [];
    const whereParts = [];

    for (const w of this._wheres) {
      const colField = (w.field === 'id' && existingCols.includes('firestore_id')) 
        ? 'firestore_id' 
        : w.field;

      if (!existingCols.includes(colField)) continue;

      let op = w.op;
      if (op === '==') op = '=';

      if (op === 'in' && Array.isArray(w.val)) {
        if (w.val.length === 0) {
          whereParts.push('1 = 0');
        } else {
          whereParts.push(`\`${colField}\` IN (${w.val.map(() => '?').join(', ')})`);
          params.push(...w.val);
        }
      } else if (op === 'array-contains') {
        whereParts.push(`\`${colField}\` LIKE ?`);
        params.push(`%${w.val}%`);
      } else {
        whereParts.push(`\`${colField}\` ${op} ?`);
        params.push(w.val);
      }
    }

    if (whereParts.length > 0) {
      sql += ' WHERE ' + whereParts.join(' AND ');
    }

    if (this._orderBys.length > 0) {
      const orders = this._orderBys
        .filter(o => existingCols.includes(o.field))
        .map(o => `\`${o.field}\` ${o.direction === 'desc' ? 'DESC' : 'ASC'}`);
      if (orders.length > 0) {
        sql += ' ORDER BY ' + orders.join(', ');
      }
    }

    if (this._limit !== null && this._limit !== undefined) {
      sql += ' LIMIT ' + Number(this._limit);
    }

    const [rows] = await pool.query(sql, params);
    return new QuerySnapshot(rows);
  }

  doc(id) {
    return new DocumentReference(this.colName, id);
  }

  async add(data) {
    const docId = generateDocId();
    const docRef = new DocumentReference(this.colName, docId);
    await docRef.set(data);
    return docRef;
  }
}

class FirestoreMock {
  constructor() {
    this._pool = pool;
  }

  collection(name) {
    return new Query(name);
  }

  settings() {}
}

const FieldValue = {
  serverTimestamp: () => new Date().toISOString(),
  delete: () => null,
  arrayUnion: (...elements) => elements,
  arrayRemove: (...elements) => []
};

module.exports = {
  getFirestore: () => new FirestoreMock(),
  FieldValue,
  pool
};

