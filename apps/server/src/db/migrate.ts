import 'dotenv/config';
import { pool, db } from './client.js';
import { migrate } from 'drizzle-orm/node-postgres/migrator';

async function waitForDb(maxAttempts = 30, delayMs = 1000) {
  let attempt = 0;
  while (attempt < maxAttempts) {
    attempt++;
    try {
      await pool.query('select 1');
      console.log(`[migrate] DB is ready (attempt ${attempt})`);
      return;
    } catch (err) {
      console.log(`[migrate] Waiting for DB... (${attempt}/${maxAttempts})`);
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  throw new Error('DB not ready in time');
}

async function run() {
  try {
    await waitForDb();
    await migrate(db, { migrationsFolder: './drizzle' });
    console.log('[migrate] Migrations complete');
  } catch (err) {
    console.error('[migrate] Failed to run migrations', err);
    process.exit(1);
  } finally {
    await pool.end().catch(() => {});
  }
}

run();

