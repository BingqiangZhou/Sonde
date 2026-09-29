import type { MetaFunction } from 'react-router';

import { renderMarkdown } from '~/lib/markdown.ts';

import changelogSource from '../../../../CHANGELOG.md?raw';

export const meta: MetaFunction = () => [
  { title: '更新日志 — 声读' },
  { name: 'description', content: '声读 Sonde 的版本更新日志：每个版本的功能、修复与重构。' },
];

/** 渲染仓库中文版 CHANGELOG（去掉文件头的通用说明，从第一个版本段开始）。 */
function changelogHtml(): string {
  const firstSection = changelogSource.indexOf('## [');
  const body = firstSection >= 0 ? changelogSource.slice(firstSection) : changelogSource;
  return renderMarkdown(body);
}

export default function Changelog() {
  return (
    <section className="py-8">
      <header className="rule-double pb-4 text-center">
        <h1 className="font-serif text-2xl font-bold tracking-wide">更新日志</h1>
        <p className="mt-2 text-xs tracking-widest text-stone-400">
          声读每个版本的新增与修复 · 与仓库 CHANGELOG.md 同步
        </p>
      </header>

      <div
        className="changelog-body mt-8"
        // 内容来自仓库自身的 CHANGELOG.md（构建时打包，受信非用户输入）
        dangerouslySetInnerHTML={{ __html: changelogHtml() }}
      />
    </section>
  );
}
