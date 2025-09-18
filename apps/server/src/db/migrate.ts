import 'dotenv/config';
import { pool, db } from './client.js';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import fs from 'fs';
import path from 'path';

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
    const migrationsFolder = path.resolve(process.cwd(), './drizzle');
    const journalPath = path.join(migrationsFolder, 'meta', '_journal.json');
    if (fs.existsSync(journalPath)) {
      await migrate(db, { migrationsFolder });
      console.log('[migrate] Migrations complete');
    } else {
      // Fallback: run raw .sql files (idempotent) if journal is absent
      console.warn('[migrate] No meta/_journal.json found. Running SQL files in drizzle/ as fallback.');
      if (!fs.existsSync(migrationsFolder)) {
        console.warn('[migrate] No drizzle folder found. Skipping migrations.');
      } else {
        const files = fs
          .readdirSync(migrationsFolder)
          .filter((f) => f.endsWith('.sql'))
          .sort();
        if (files.length === 0) {
          console.warn('[migrate] No .sql files in drizzle/. Skipping.');
        } else {
          for (const f of files) {
            const full = path.join(migrationsFolder, f);
            const sql = fs.readFileSync(full, 'utf8');
            if (sql.trim().length === 0) continue;
            console.log(`[migrate] Applying ${f} ...`);
            await pool.query(sql);
          }
          console.log('[migrate] SQL fallback complete');
        }
      }
    }
  } catch (err) {
    console.error('[migrate] Failed to run migrations', err);
    process.exit(1);
  } finally {
    await pool.end().catch(() => {});
  }
}

run();
