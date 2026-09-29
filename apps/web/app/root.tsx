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
      <body className="min-h-screen bg-stone-50 text-stone-900 antialiased">
        <header className="border-b border-stone-200 bg-white">
          <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-3">
            <Link to="/" className="text-lg font-bold tracking-wide">
              声读 <span className="text-sm font-normal text-stone-400">Sonde</span>
            </Link>
            <nav className="flex gap-4 text-sm text-stone-600">
              <Link to="/" className="hover:text-stone-900">首页</Link>
              <Link to="/daily" className="hover:text-stone-900">日报</Link>
              <Link to="/archive" className="hover:text-stone-900">全部</Link>
              <Link to="/about" className="hover:text-stone-900">关于</Link>
            </nav>
          </div>
        </header>
        <main className="mx-auto max-w-3xl px-4 py-8">{children}</main>
        <footer className="border-t border-stone-200 py-6 text-center text-xs text-stone-400">
          声读 · 个人播客知识库 · 内容版权归原作者所有 ·{' '}
          <a href="/admin" className="hover:text-stone-600">
            后台
          </a>
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
