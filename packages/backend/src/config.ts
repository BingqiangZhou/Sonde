/** Central env-based configuration (single source of truth for all processes). */

export interface Config {
  databaseUrl: string;
  apiPort: number;
  webPort: number;
  apiUrl: string;
  siteUrl: string;
}

function str(env: NodeJS.ProcessEnv, key: string, fallback = ''): string {
  const value = env[key];
  return value === undefined || value === '' ? fallback : value;
}

function num(env: NodeJS.ProcessEnv, key: string, fallback: number): number {
  const parsed = Number.parseInt(env[key] ?? '', 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  return {
    databaseUrl: str(env, 'DATABASE_URL', 'postgres://sonde:sonde@localhost:5432/sonde'),
    apiPort: num(env, 'API_PORT', 3001),
    webPort: num(env, 'WEB_PORT', 3000),
    apiUrl: str(env, 'API_URL', 'http://localhost:3001'),
    siteUrl: str(env, 'SITE_URL', 'http://localhost:3000'),
  };
}
