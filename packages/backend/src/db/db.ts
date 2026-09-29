/** Postgres access layer: a lazily-created pool, a tagged-template SQL builder,
 *  a query helper and a transaction helper. No ORM. */

import pg from 'pg';

import { loadConfig } from '../config.ts';

export type QueryParams = unknown[];

export interface SqlFragment {
  text: string;
  values: QueryParams;
}

let pool: pg.Pool | null = null;

export function getPool(): pg.Pool {
  if (pool === null) {
    pool = new pg.Pool({
      connectionString: loadConfig().databaseUrl,
      max: 10,
    });
  }
  return pool;
}

/** Replace an existing pool (used by tests to point at another database). */
export function setPool(next: pg.Pool): void {
  pool = next;
}

/** Tagged-template SQL builder: sql`SELECT * FROM t WHERE id = ${id}` */
export function sql(strings: TemplateStringsArray, ...values: unknown[]): SqlFragment {
  let text = strings[0] ?? '';
  for (let i = 1; i < strings.length; i++) {
    text += `$${i}${strings[i]}`;
  }
  return { text, values };
}

/** Execute a query (tagged fragment or raw text with optional params). */
export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  fragment: SqlFragment | string,
  values?: QueryParams,
): Promise<pg.QueryResult<T>> {
  const q = typeof fragment === 'string' ? { text: fragment, values: values ?? [] } : fragment;
  return getPool().query<T>(q.text, q.values);
}

/** Execute a query and return all rows. */
export async function rows<T extends pg.QueryResultRow = pg.QueryResultRow>(
  fragment: SqlFragment | string,
  values?: QueryParams,
): Promise<T[]> {
  return (await query<T>(fragment, values)).rows;
}

/** Execute a query and return the first row or null. */
export async function row<T extends pg.QueryResultRow = pg.QueryResultRow>(
  fragment: SqlFragment | string,
  values?: QueryParams,
): Promise<T | null> {
  return ((await query<T>(fragment, values)).rows[0] as T | undefined) ?? null;
}

/** Run `fn` inside a transaction; commits on success, rolls back on throw. */
export async function withTx<T>(fn: (client: pg.PoolClient) => Promise<T>): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function ping(): Promise<boolean> {
  const result = await row<{ ok: number }>(sql`SELECT 1 AS ok`);
  return result?.ok === 1;
}

export async function closeDb(): Promise<void> {
  if (pool !== null) {
    await pool.end();
    pool = null;
  }
}
