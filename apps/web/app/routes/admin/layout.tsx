import type { MetaFunction } from 'react-router';
import { NavLink, Outlet, useLoaderData, useNavigation } from 'react-router';

import { apiGet, forwardHeaders } from '~/lib/api.server.ts';

export const meta: MetaFunction = () => [{ title: '后台 — 声读' }];

export async function loader({ request }: { request: Request }) {
  const session = await apiGet<{ authenticated: boolean }>('/admin/session', forwardHeaders(request));
  return { authenticated: session?.authenticated ?? false };
}

const NAV = [
  { to: '/admin', label: '仪表盘', end: true },
  { to: '/admin/sources', label: '订阅源', end: false },
  { to: '/admin/episodes', label: '单集', end: false },
  { to: '/admin/reports', label: '日报', end: false },
  { to: '/admin/costs', label: '成本', end: false },
];

export default function AdminLayout() {
  const { authenticated } = useLoaderData<typeof loader>();
  const navigation = useNavigation();

  if (!authenticated) {
    return (
      <section className="py-16 text-center text-stone-500">
        <a href="/admin/login" className="text-stone-700 underline">
          前往登录
        </a>
      </section>
    );
  }

  return (
    <div className="py-6">
      <div className="flex items-center justify-between border-b border-stone-200 pb-3">
        <nav className="flex gap-4 text-sm">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                isActive ? 'font-semibold text-stone-900' : 'text-stone-500 hover:text-stone-900'
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <a href="/" className="text-xs text-stone-400 hover:text-stone-600">
          返回站点 ↗
        </a>
      </div>
      <div className={navigation.state === 'loading' ? 'opacity-50' : ''}>
        <Outlet />
      </div>
    </div>
  );
}
