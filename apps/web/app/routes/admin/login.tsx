import type { MetaFunction } from 'react-router';
import { Form, useNavigate } from 'react-router';
import { useState } from 'react';

import { adminSend } from '~/lib/admin-api.ts';

export const meta: MetaFunction = () => [{ title: '登录 — 声读后台' }];

export async function action({ request }: { request: Request }) {
  const form = await request.formData();
  const password = String(form.get('password') ?? '');
  const res = await fetch('/api/admin/login', {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ password }),
  });
  if (res.ok) {
    return { ok: true };
  }
  return { ok: false, error: (await res.json().catch(() => ({}))).error ?? '登录失败' };
}

export default function AdminLogin() {
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  return (
    <section className="mx-auto max-w-xs py-16">
      <h1 className="text-center text-xl font-bold text-stone-900">声读后台</h1>
      <Form
        method="post"
        onSubmit={async (event) => {
          event.preventDefault();
          const form = event.currentTarget;
          const data = new FormData(form);
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
        <input
          type="password"
          name="password"
          required
          placeholder="管理员密码"
          className="mt-6 w-full rounded-md border border-stone-300 px-3 py-2 text-sm focus:border-stone-500 focus:outline-none"
        />
        {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="mt-4 w-full rounded-md bg-stone-900 px-4 py-2 text-sm font-medium text-white hover:bg-stone-700 disabled:opacity-50"
        >
          {busy ? '登录中…' : '登录'}
        </button>
      </Form>
    </section>
  );
}
