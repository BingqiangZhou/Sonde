import type { LinksFunction, MetaFunction } from 'react-router';
import {
  Link,
  Links,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration,
} from 'react-router';

import stylesheet from './app.css?url';

export const links: LinksFunction = () => [
  { rel: 'stylesheet', href: stylesheet },
  { rel: 'icon', href: '/favicon.svg', type: 'image/svg+xml' },
];

export const meta: MetaFunction = () => [
  { title: '声读 — 每天一份值得读的播客日报' },
  { name: 'description', content: '声读自动订阅播客、转写音频、AI 评分筛选，每天早晨生成一份可读的中文播客日报。' },
];

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <Meta />
        <Links />
      </head>
      <body className="min-h-screen bg-paper font-sans text-ink antialiased">
        <header className="sticky top-0 z-40 border-b border-stone-300/80 bg-paper/90 backdrop-blur">
          <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-3">
            <Link to="/" className="group flex items-baseline gap-1.5">
              <span className="font-serif text-xl font-bold tracking-wide">声读</span>
              <span className="text-xs font-medium tracking-widest text-stone-400 transition-colors group-hover:text-vermilion">
                SONDE
              </span>
            </Link>
            <nav className="flex gap-5 text-sm text-stone-600">
              <Link to="/" className="hover:text-ink">首页</Link>
              <Link to="/daily" className="hover:text-ink">日报</Link>
              <Link to="/archive" className="hover:text-ink">全部</Link>
              <Link to="/about" className="hover:text-ink">关于</Link>
            </nav>
          </div>
          <div className="border-t border-stone-200" />
        </header>
        <main className="mx-auto max-w-3xl px-4 py-8">{children}</main>
        <footer className="mt-16 border-t border-stone-300 py-8">
          <div className="mx-auto max-w-3xl px-4 text-center text-xs leading-relaxed text-stone-400">
            <div className="rule-double mx-auto mb-3 w-16" />
            声读 · 个人播客知识库 · 内容版权归原作者所有 ·{' '}
            <a href="/admin" className="hover:text-stone-600">
              后台
            </a>
          </div>
        </footer>
        <ScrollRestoration />
        <Scripts />
      </body>
    </html>
  );
}

export default function App() {
  return <Outlet />;
}
