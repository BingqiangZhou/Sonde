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
      <section className="py-20 text-center text-stone-500">
        <p className="font-serif text-xl">需要登录后访问</p>
        <a
          href="/admin/login"
          className="mt-5 inline-block rounded-md bg-ink px-5 py-2 text-sm font-medium text-paper hover:bg-vermilion"
        >
          前往登录
        </a>
      </section>
    );
  }

  return (
    <div className="py-6">
      {/* 控制台顶栏 */}
      <div className="-mx-4 -mt-8 mb-6 border-b border-stone-700 bg-ink px-4 py-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <span className="font-serif text-lg font-bold text-paper">声读控制台</span>
            <span className="rounded-sm bg-vermilion px-1.5 py-px text-[10px] font-medium tracking-widest text-white">
              ADMIN
            </span>
          </div>
          <nav className="flex flex-wrap gap-1">
            {NAV.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                end={item.end}
                className={({ isActive }) =>
                  `rounded-md px-3 py-1.5 text-sm transition-colors ${
                    isActive
                      ? 'bg-paper font-semibold text-ink'
                      : 'text-stone-300 hover:bg-stone-800 hover:text-paper'
                  }`
                }
              >
                {item.label}
              </NavLink>
            ))}
          </nav>
        </div>
        <div className="mt-2 flex justify-end">
          <a href="/" className="text-xs text-stone-400 hover:text-paper">
            返回站点 ↗
          </a>
        </div>
      </div>

      <div className={navigation.state === 'loading' ? 'opacity-50 transition-opacity' : 'transition-opacity'}>
        <Outlet />
      </div>
    </div>
  );
}
