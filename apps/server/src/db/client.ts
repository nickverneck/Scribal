import 'dotenv/config';
import { drizzle } from 'drizzle-orm/node-postgres';
import pg from 'pg';
import * as schema from './schema.js';

const { Pool } = pg;

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.warn('[DB] Missing DATABASE_URL environment variable');
}

export const pool = new Pool({ connectionString });
export const db = drizzle(pool, { schema });

