import type { LinksFunction, MetaFunction } from 'react-router';
import { Link, Links, Meta, Outlet, Scripts, ScrollRestoration, useNavigation, useRouteError } from 'react-router';

import { SITE } from '@sonde/industry';

import { Sidebar } from './components/Sidebar.tsx';
import { useThemeSync } from './components/ThemeControls.tsx';

import stylesheet from './app.css?url';

export const links: LinksFunction = () => [
  { rel: 'stylesheet', href: stylesheet },
  { rel: 'icon', href: '/favicon.svg', type: 'image/svg+xml' },
];

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

/** 首屏初始化：在样式加载后、渲染前给 <html> 打 .dark(主题,避免深色用户看到白色闪烁)
 *  和 .sb-open(侧栏,避免展开态用户看到收起闪动)。默认展开,存了 'closed' 才收起。
 *  存储键与 lib/theme.ts(sonde-theme)、lib/sidebar.ts(sonde-sidebar)保持一致。 */
const THEME_INIT_SCRIPT = `(function(){try{var t=localStorage.getItem('sonde-theme')||'system';var d=t==='dark'||(t!=='light'&&window.matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);if(localStorage.getItem('sonde-sidebar')!=='closed'){document.documentElement.classList.add('sb-open');}}catch(e){}})();`;

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <Meta />
        <Links />
        <script dangerouslySetInnerHTML={{ __html: THEME_INIT_SCRIPT }} />
      </head>
      <body className="min-h-dvh bg-paper font-sans text-ink antialiased">
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

/** 单页站点外壳:左缘站点侧栏(刊头/主题切换/版权,可收起展开)+ 居中正文栏。 */
function SiteShell({ children }: { children: React.ReactNode }) {
  const navigation = useNavigation();
  return (
    <div className="flex min-h-dvh">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:fixed focus:left-3 focus:top-3 focus:z-50 focus:rounded-md focus:bg-white focus:px-3 focus:py-2 focus:text-sm focus:shadow"
      >
        跳到正文
      </a>
      <Sidebar />
      <main id="main" className="min-w-0 flex-1">
        <div
          className={`mx-auto w-full max-w-3xl px-4 transition-opacity sm:px-6 ${
            navigation.state === 'loading' ? 'opacity-50' : ''
          }`}
        >
          {children}
        </div>
      </main>
    </div>
  );
}

export default function App() {
  // 水合后重新应用主题（React 水合会剥掉内联脚本加在 <html> 上的 .dark），并跟踪系统偏好
  useThemeSync();
  return (
    <SiteShell>
      <Outlet />
    </SiteShell>
  );
}

export function ErrorBoundary() {
  const error = useRouteError();
  // 鸭子判型：loader 抛出的错误经 SSR 序列化后 instanceof 必失效，只能看 status。
  // 路由未匹配的错误带 status:404 → 404 卡片；无 status 的未知错误（如 loader 自身抛异常）
  // 按"服务暂时不可用"处理，不再误标成 404（P1-9 的原始诉求）。
  const status = (error as { status?: unknown } | null)?.status;
  const unavailable = !(typeof status === 'number' && status < 500);
  if (unavailable) {
    return (
      <div className="flex min-h-[70vh] items-center justify-center px-4 py-16">
        <div className="max-w-sm text-center">
          <div className="mono text-xs text-stone-400">服务暂时不可用</div>
          <h1 className="mt-1.5 font-serif text-xl font-bold">API 暂时无法访问</h1>
          <p className="mt-2 text-sm leading-relaxed text-stone-500">
            数据服务暂时不可用，内容没有丢失，稍后刷新即可恢复。
          </p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="mt-6 inline-block rounded-md bg-ink px-5 py-2 text-sm font-medium text-paper hover:bg-vermilion"
          >
            刷新重试
          </button>
        </div>
      </div>
    );
  }
  return (
    <div className="flex min-h-[70vh] items-center justify-center px-4 py-16">
      <div className="max-w-sm text-center">
        <div className="mono text-xs text-stone-400">404</div>
        <h1 className="mt-1.5 font-serif text-xl font-bold">这里没有内容</h1>
        <p className="mt-2 text-sm leading-relaxed text-stone-500">你访问的页面不存在。</p>
        <Link
          to="/"
          className="mt-6 inline-block rounded-md bg-ink px-5 py-2 text-sm font-medium text-paper hover:bg-vermilion"
        >
          回到首页
        </Link>
      </div>
    </div>
  );
}
