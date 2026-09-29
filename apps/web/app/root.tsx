import type { LinksFunction, MetaFunction } from 'react-router';
import {
  Link,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
  useLocation,
  useNavigation,
} from 'react-router';

import { SITE } from '@sonde/industry';

import { MobileTabBar } from './components/shell/MobileTabBar.tsx';
import { Sidebar } from './components/shell/Sidebar.tsx';

import stylesheet from './app.css?url';

export const links: LinksFunction = () => [
  { rel: 'stylesheet', href: stylesheet },
  { rel: 'icon', href: '/favicon.svg', type: 'image/svg+xml' },
];

export const meta: MetaFunction = () => [
  { title: SITE.homeTitle },
  { name: 'description', content: SITE.description },
];

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <Meta />
        <Links />
      </head>
      <body className="min-h-dvh bg-paper font-sans text-ink antialiased">
        {children}
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

/** 侧栏 + 主栏 + 移动底栏的站点外壳（admin 有自己的 chrome，不套此壳）。 */
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
      <main id="main" className="min-w-0 flex-1 pb-[calc(72px+env(safe-area-inset-bottom))] lg:pb-12 lg:pt-8">
        <div
          className={`mx-auto w-full max-w-3xl px-4 transition-opacity lg:px-0 ${
            navigation.state === 'loading' ? 'opacity-50' : ''
          }`}
        >
          {children}
        </div>
      </main>
      <MobileTabBar />
    </div>
  );
}

export default function App() {
  const { pathname } = useLocation();
  // admin 使用完全独立的 chrome
  if (pathname === '/admin' || pathname.startsWith('/admin/')) {
    return <Outlet />;
  }
  return (
    <SiteShell>
      <Outlet />
    </SiteShell>
  );
}

export function ErrorBoundary() {
  return (
    <div className="flex min-h-[70vh] items-center justify-center px-4 py-16">
      <div className="max-w-sm text-center">
        <div className="mono text-xs text-stone-400">404</div>
        <h1 className="mt-1.5 font-serif text-xl font-bold">这里没有内容</h1>
        <p className="mt-2 text-sm leading-relaxed text-stone-500">你访问的页面不存在，或内容尚未生成。</p>
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
