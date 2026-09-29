import type { MetaFunction } from 'react-router';
import { Form, useNavigate } from 'react-router';
import { useState } from 'react';

import { adminSend } from '~/lib/admin-api.ts';

export const meta: MetaFunction = () => [{ title: '登录 — 声读后台' }];

export default function AdminLogin() {
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  return (
    <section className="flex justify-center py-16">
      <div className="w-full max-w-sm border border-stone-300 bg-white p-8 shadow-sm">
        <div className="text-center">
          <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-xl bg-ink font-serif text-xl font-bold text-paper">
            声
          </div>
          <h1 className="mt-4 font-serif text-xl font-bold">声读控制台</h1>
          <p className="mt-1 text-xs tracking-widest text-stone-400">SONDE ADMIN</p>
        </div>
        <Form
          method="post"
          onSubmit={async (event) => {
            event.preventDefault();
            const data = new FormData(event.currentTarget);
            setBusy(true);
            setError(null);
            try {
              await adminSend('/login', 'POST', { password: String(data.get('password') ?? '') });
              navigate('/admin');
            } catch (err) {
              setError(err instanceof Error ? err.message : '登录失败');
            } finally {
              setBusy(false);
            }
          }}
        >
          <label className="mt-8 block text-xs font-medium text-stone-500" htmlFor="password">
            管理员密码
          </label>
          <input
            id="password"
            type="password"
            name="password"
            required
            autoComplete="current-password"
            placeholder="请输入 .env 中配置的 ADMIN_PASSWORD"
            className="mt-1.5 w-full rounded-md border border-stone-300 px-3 py-2 text-sm placeholder:text-stone-300 focus:border-vermilion focus:outline-none"
          />
          {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
          <button
            type="submit"
            disabled={busy}
            className="mt-5 w-full rounded-md bg-ink px-4 py-2.5 text-sm font-medium text-paper transition-colors hover:bg-vermilion disabled:opacity-50"
          >
            {busy ? '登录中…' : '登 录'}
          </button>
        </Form>
      </div>
    </section>
  );
}
