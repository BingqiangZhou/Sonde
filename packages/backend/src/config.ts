/** Central env-based configuration (single source of truth for all processes). */

export interface Config {
  databaseUrl: string;
  apiPort: number;
  webPort: number;
  apiUrl: string;
  siteUrl: string;
  llmBaseUrl: string;
  llmApiKey: string;
  llmModel: string;
  transcriptionBaseUrl: string;
  transcriptionApiKey: string;
  transcriptionModel: string;
  adminPassword: string;
  sessionSecret: string;
  workConcurrency: number;
  reportTimezone: string;
  dataDir: string;
  /** 播客发现（iTunes Search API）使用的国家商店码 */
  itunesCountries: string[];
  /** 仅 iTunes 客户端使用的自定义 DNS（如 1.1.1.1），空 = 系统默认 */
  itunesDns: string;
  /** 仅 iTunes 客户端使用的 HTTP 代理（如 http://host.docker.internal:7897），空 = 直连 */
  itunesProxyUrl: string;
}

function str(env: NodeJS.ProcessEnv, key: string, fallback = ''): string {
  const value = env[key];
  return value === undefined || value === '' ? fallback : value;
}

function num(env: NodeJS.ProcessEnv, key: string, fallback: number): number {
  const parsed = Number.parseInt(env[key] ?? '', 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function countryCodes(env: NodeJS.ProcessEnv, key: string, fallback: string): string[] {
  const raw = env[key] && env[key] !== '' ? env[key] : fallback;
  const codes = [
    ...new Set(
      raw
        .split(',')
        .map((code) => code.trim().toUpperCase())
        .filter((code) => /^[A-Z]{2}$/.test(code)),
    ),
  ];
  return codes.length > 0 ? codes : ['CN'];
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const databaseUrl = str(
    env,
    'DATABASE_URL',
    'postgres://sonde:sonde@localhost:5432/sonde',
  );
  return {
    databaseUrl,
    apiPort: num(env, 'API_PORT', 3001),
    webPort: num(env, 'WEB_PORT', 3000),
    apiUrl: str(env, 'API_URL', 'http://localhost:3001'),
    siteUrl: str(env, 'SITE_URL', 'http://localhost:3000'),
    llmBaseUrl: str(env, 'LLM_BASE_URL'),
    llmApiKey: str(env, 'LLM_API_KEY'),
    llmModel: str(env, 'LLM_MODEL'),
    transcriptionBaseUrl: str(env, 'TRANSCRIPTION_BASE_URL'),
    transcriptionApiKey: str(env, 'TRANSCRIPTION_API_KEY'),
    transcriptionModel: str(env, 'TRANSCRIPTION_MODEL'),
    adminPassword: str(env, 'ADMIN_PASSWORD'),
    sessionSecret: str(env, 'SESSION_SECRET'),
    workConcurrency: num(env, 'WORK_CONCURRENCY', 2),
    reportTimezone: str(env, 'REPORT_TIMEZONE', 'Asia/Shanghai'),
    dataDir: str(env, 'DATA_DIR', './data'),
    itunesCountries: countryCodes(env, 'ITUNES_COUNTRIES', 'CN,US'),
    itunesDns: str(env, 'ITUNES_DNS'),
    itunesProxyUrl: str(env, 'ITUNES_PROXY_URL'),
  };
}
