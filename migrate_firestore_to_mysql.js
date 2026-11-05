/**
 * Firestore to MySQL Migration Script
 * Project: buildtrack-sotalbocons-system
 * 
 * Collections migrated:
 *  1. admins
 *  2. assets
 *  3. attendance
 *  4. borrow_history
 *  5. budget_additions
 *  6. cash_advances
 *  7. expenses
 *  8. materials
 *  9. projects
 *  10. schedules
 *  11. workers
 */

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'firebase-service-account.json');

if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error(`\n[ERROR] Hindi mahanap ang service account file:`);
  console.error(`  ${SERVICE_ACCOUNT_PATH}`);
  console.error(`\nPaki-download ang Service Account JSON mula sa Firebase Console:`);
  console.error(`  Project Settings -> Service accounts -> "Generate new private key"`);
  console.error(`at i-save ito bilang 'firebase-service-account.json' sa folder na ito.\n`);
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

// List of all collections to extract
const COLLECTIONS = [
  'admins',
  'assets',
  'attendance',
  'borrow_history',
  'budget_additions',
  'cash_advances',
  'expenses',
  'materials',
  'projects',
  'schedules',
  'workers'
];

function escapeSqlString(val) {
  if (val === null || val === undefined) return 'NULL';
  if (typeof val === 'boolean') return val ? '1' : '0';
  if (typeof val === 'number') return isNaN(val) ? 'NULL' : String(val);
  if (typeof val === 'object') {
    // Check if Firestore timestamp
    if (val._seconds !== undefined || (typeof val.toDate === 'function')) {
      const d = typeof val.toDate === 'function' ? val.toDate() : new Date(val._seconds * 1000);
      return `'${d.toISOString().slice(0, 19).replace('T', ' ')}'`;
    }
    return `'${JSON.stringify(val).replace(/[\0\x08\x09\x1a\n\r"'\\\%]/g, char => {
      switch (char) {
        case "\0": return "\\0";
        case "\x08": return "\\b";
        case "\x09": return "\\t";
        case "\x1a": return "\\z";
        case "\n": return "\\n";
        case "\r": return "\\r";
        case "\"": case "'": case "\\": case "%":
          return "\\" + char;
        default: return char;
      }
    })}'`;
  }
  const str = String(val);
  return `'${str.replace(/[\0\x08\x09\x1a\n\r"'\\\%]/g, char => {
    switch (char) {
      case "\0": return "\\0";
      case "\x08": return "\\b";
      case "\x09": return "\\t";
      case "\x1a": return "\\z";
      case "\n": return "\\n";
      case "\r": return "\\r";
      case "\"": case "'": case "\\": case "%":
        return "\\" + char;
      default: return char;
    }
  })}'`;
}

function sanitizeColName(name) {
  return '`' + name.replace(/`/g, '``') + '`';
}

function inferSqlType(values) {
  let hasString = false;
  let hasNumber = false;
  let hasBoolean = false;
  let hasObject = false;
  let maxLen = 0;
  let isAllInteger = true;

  for (const v of values) {
    if (v === null || v === undefined) continue;
    if (typeof v === 'boolean') {
      hasBoolean = true;
    } else if (typeof v === 'number') {
      hasNumber = true;
      if (!Number.isInteger(v)) isAllInteger = false;
    } else if (typeof v === 'object') {
      hasObject = true;
      const s = JSON.stringify(v);
      if (s.length > maxLen) maxLen = s.length;
    } else {
      hasString = true;
      const s = String(v);
      if (s.length > maxLen) maxLen = s.length;
    }
  }

  if (hasObject) return 'LONGTEXT';
  if (hasString) {
    if (maxLen > 255) return 'LONGTEXT';
    return maxLen > 100 ? 'VARCHAR(255)' : 'VARCHAR(150)';
  }
  if (hasNumber) {
    return isAllInteger ? 'BIGINT' : 'DECIMAL(12, 2)';
  }
  if (hasBoolean) return 'TINYINT(1)';
  return 'VARCHAR(255)';
}

async function migrate() {
  console.log('====================================================');
  console.log(`Starting Firestore to MySQL Data Export...`);
  console.log(`Firebase Project: ${serviceAccount.project_id || 'buildtrack-sotalbocons-system'}`);
  console.log('====================================================\n');

  const sqlStatements = [];
  const dbName = 'buildtrack_db';

  sqlStatements.push(`-- Generated Migration Script from Firestore`);
  sqlStatements.push(`-- Target Database: ${dbName}`);
  sqlStatements.push(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
  sqlStatements.push(`USE \`${dbName}\`;\n`);

  const summary = {};

  for (const colName of COLLECTIONS) {
    console.log(`Fetching collection: ${colName}...`);
    try {
      const snap = await db.collection(colName).get();
      console.log(`  -> Found ${snap.size} documents.`);
      summary[colName] = snap.size;

      if (snap.empty) {
        // Create an empty fallback table with basic structure
        sqlStatements.push(`-- Table structure for empty collection: ${colName}`);
        sqlStatements.push(`CREATE TABLE IF NOT EXISTS \`${colName}\` (`);
        sqlStatements.push(`  \`firestore_id\` VARCHAR(128) PRIMARY KEY,`);
        sqlStatements.push(`  \`data_json\` LONGTEXT,`);
        sqlStatements.push(`  \`created_at\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP`);
        sqlStatements.push(`) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n`);
        continue;
      }

      // Collect all field names and sample values across all documents
      const docsData = [];
      const fieldValues = {};

      snap.forEach(doc => {
        const data = doc.data();
        docsData.push({ firestore_id: doc.id, ...data });
        for (const [k, v] of Object.entries(data)) {
          if (!fieldValues[k]) fieldValues[k] = [];
          fieldValues[k].push(v);
        }
      });

      // Generate CREATE TABLE statement
      const columnDefs = [`  \`firestore_id\` VARCHAR(128) NOT NULL PRIMARY KEY`];
      const columnNames = Object.keys(fieldValues);

      for (const col of columnNames) {
        const sqlType = inferSqlType(fieldValues[col]);
        columnDefs.push(`  ${sanitizeColName(col)} ${sqlType} NULL`);
      }

      sqlStatements.push(`-- Table structure for: ${colName}`);
      sqlStatements.push(`DROP TABLE IF EXISTS \`${colName}\`;`);
      sqlStatements.push(`CREATE TABLE \`${colName}\` (\n${columnDefs.join(',\n')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;\n`);

      // Generate INSERT INTO statements
      const allCols = ['firestore_id', ...columnNames];
      const insertHeader = `INSERT INTO \`${colName}\` (${allCols.map(sanitizeColName).join(', ')}) VALUES`;

      const rowChunks = [];
      const CHUNK_SIZE = 50;

      for (let i = 0; i < docsData.length; i += CHUNK_SIZE) {
        const chunk = docsData.slice(i, i + CHUNK_SIZE);
        const valueTuples = chunk.map(row => {
          const vals = allCols.map(col => escapeSqlString(row[col]));
          return `(${vals.join(', ')})`;
        });
        rowChunks.push(`${insertHeader}\n${valueTuples.join(',\n')};`);
      }

      if (rowChunks.length > 0) {
        sqlStatements.push(`-- Data for: ${colName}`);
        sqlStatements.push(rowChunks.join('\n\n'));
        sqlStatements.push('\n');
      }

    } catch (err) {
      console.error(`  [WARN] Failed to fetch collection ${colName}:`, err.message);
    }
  }

  const outFilePath = path.join(__dirname, 'firestore_export_to_mysql.sql');
  fs.writeFileSync(outFilePath, sqlStatements.join('\n'), 'utf8');

  console.log('\n====================================================');
  console.log(`[SUCCESS] SQL Dump file successfully created!`);
  console.log(`File: ${outFilePath}`);
  console.log('Collection Summary:');
  console.table(summary);
  console.log('====================================================\n');
}

migrate().catch(err => {
  console.error('\n[FATAL ERROR]:', err);
  process.exit(1);
});
