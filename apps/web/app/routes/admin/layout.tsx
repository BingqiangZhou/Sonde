import type { MetaFunction } from 'react-router';
import { NavLink, Outlet, useLoaderData, useNavigation } from 'react-router';

import { apiGet, forwardHeaders } from '~/lib/api.server.ts';

import { IconCoins, IconDisc, IconGrid, IconNews, IconRadio } from '~/components/icons.tsx';

export const meta: MetaFunction = () => [{ title: '后台 — 声读' }];

export async function loader({ request }: { request: Request }) {
  const session = await apiGet<{ authenticated: boolean }>('/admin/session', forwardHeaders(request));
  return { authenticated: session?.authenticated ?? false };
}

const NAV = [
  { to: '/admin', label: '仪表盘', icon: IconGrid, end: true },
  { to: '/admin/sources', label: '订阅源', icon: IconRadio, end: false },
  { to: '/admin/episodes', label: '单集', icon: IconDisc, end: false },
  { to: '/admin/reports', label: '日报', icon: IconNews, end: false },
  { to: '/admin/costs', label: '成本', icon: IconCoins, end: false },
];

export default function AdminLayout() {
  const { authenticated } = useLoaderData<typeof loader>();
  const navigation = useNavigation();

  if (!authenticated) {
    return (
      <div className="flex min-h-dvh items-center justify-center px-4">
        <div className="text-center">
          <p className="font-serif text-xl">需要登录后访问</p>
          <a
            href="/admin/login"
            className="mt-5 inline-block rounded-md bg-ink px-5 py-2 text-sm font-medium text-paper hover:bg-vermilion"
          >
            前往登录
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-dvh">
      {/* 桌面深色侧栏 */}
      <aside className="sticky top-0 hidden h-dvh w-56 shrink-0 flex-col bg-ink px-3 pb-4 pt-6 lg:flex">
        <div className="mb-6 flex h-11 items-center gap-2.5 px-1.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-paper font-serif text-base font-bold text-ink">
            声
          </span>
          <span className="flex flex-col leading-none">
            <span className="font-serif text-base font-bold text-paper">控制台</span>
            <span className="mt-1 text-[10px] font-medium tracking-[0.28em] text-stone-500">ADMIN</span>
          </span>
        </div>

        <nav aria-label="后台导航" className="-mx-1 flex-1 overflow-y-auto px-1">
          <div className="px-2.5 pb-1 pt-2 text-[11px] tracking-wider text-stone-500">管理</div>
          <div className="flex flex-col gap-1">
            {NAV.map((item) => (
              <AdminSideLink key={item.to} item={item} />
            ))}
          </div>
        </nav>

        <div className="mt-2 border-t border-stone-800 px-1 pt-3">
          <a
            href="/"
            className="flex h-9 items-center gap-2.5 rounded-md px-2.5 text-[13px] text-stone-400 transition-colors hover:bg-stone-800 hover:text-paper"
          >
            返回站点 ↗
          </a>
        </div>
      </aside>

      {/* 主区域 */}
      <div className="min-w-0 flex-1">
        {/* 移动端顶栏（lg 以下） */}
        <div className="sticky top-0 z-40 bg-ink px-4 pb-2.5 pt-4 lg:hidden">
          <div className="flex items-center justify-between">
            <span className="font-serif text-base font-bold text-paper">声读控制台</span>
            <a href="/" className="text-xs text-stone-400 hover:text-paper">
              返回站点 ↗
            </a>
          </div>
          <nav className="-mx-1 mt-3 flex gap-1 overflow-x-auto px-1">
            {NAV.map((item) => (
              <MobileNavLink key={item.to} item={item} />
            ))}
          </nav>
        </div>

        <main className="px-4 py-6 lg:px-8 lg:py-8">
          <div
            className={`mx-auto w-full max-w-4xl transition-opacity ${
              navigation.state === 'loading' ? 'opacity-50' : ''
            }`}
          >
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}

interface AdminNavItem {
  to: string;
  label: string;
  icon: (props: { size?: number }) => React.ReactNode;
  end: boolean;
}

function AdminSideLink({ item }: { item: AdminNavItem }) {
  const Icon = item.icon;
  return (
    <NavLink
      to={item.to}
      end={item.end}
      prefetch="intent"
      className={({ isActive }) =>
        `flex h-10 items-center gap-2.5 rounded-md px-2.5 text-sm transition-colors duration-150 ${
          isActive
            ? 'bg-paper font-semibold text-ink'
            : 'font-medium text-stone-300 hover:bg-stone-800 hover:text-paper'
        }`
      }
    >
      {({ isActive }) => (
        <>
          <span className="flex w-[22px] shrink-0 justify-center">
            <Icon size={17} />
          </span>
          <span className="min-w-0 truncate">{item.label}</span>
        </>
      )}
    </NavLink>
  );
}

function MobileNavLink({ item }: { item: AdminNavItem }) {
  const Icon = item.icon;
  return (
    <NavLink
      to={item.to}
      end={item.end}
      className={({ isActive }) =>
        `flex flex-none items-center gap-1.5 rounded-md px-3 py-1.5 text-xs transition-colors ${
          isActive ? 'bg-paper font-semibold text-ink' : 'text-stone-300 hover:bg-stone-800'
        }`
      }
    >
      <Icon size={14} />
      {item.label}
    </NavLink>
  );
}
