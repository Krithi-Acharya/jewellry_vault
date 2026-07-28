// Quick standalone connectivity check — not part of the app itself.
// Usage (PowerShell):
//   $env:PROBE_URL="postgresql://user:pass@host:port/dbname"
//   node _probe.mjs
//   Remove-Item _probe.mjs

import pg from 'pg';
const { Client } = pg;

const connectionString = process.env.PROBE_URL;

if (!connectionString) {
  console.error('PROBE_URL environment variable is not set.');
  process.exit(1);
}

const client = new Client({ connectionString });

try {
  await client.connect();
  console.log('✅ Connected successfully.');

  const timeResult = await client.query('SELECT NOW() AS server_time');
  console.log('Server time:', timeResult.rows[0].server_time);

  const tablesResult = await client.query(`
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name
  `);
  console.log(`Found ${tablesResult.rows.length} tables:`);
  tablesResult.rows.forEach((row) => console.log(' -', row.table_name));
} catch (err) {
  console.error('❌ Connection failed:', err.message);
  process.exitCode = 1;
} finally {
  await client.end();
}
