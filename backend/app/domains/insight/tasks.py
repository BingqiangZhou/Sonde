"""Insight Celery 任务（Phase C）：单集评分、sweep 兜底、三刊成刊与 catch-up。"""

from __future__ import annotations

import logging

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.runtime import run_async, worker_session


logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=2, default_retry_delay=60)
def analyze_episode_task(self, episode_id: int) -> str:
    """对单集执行评分（+过线写作）。"""

    async def _run() -> str:
        from app.domains.insight.analyze_service import AnalyzeService

        async with worker_session("insight-analyze") as db:
            analysis = await AnalyzeService(db).analyze_episode(episode_id)
            if analysis is None:
                return f"episode {episode_id}: skipped (already analyzed)"
            return (
                f"episode {episode_id}: score={analysis.score} "
                f"selected={analysis.selected}"
            )

    return run_async(_run())


@celery_app.task(bind=True, max_retries=1)
def sweep_analyses_task(self) -> str:
    """兜底：有转录但无判定的单集批量补评分（每 30 分钟）。"""

    async def _run() -> str:
        from app.domains.insight.analyze_service import AnalyzeService

        async with worker_session("insight-sweep") as db:
            count = await AnalyzeService(db).sweep_pending(limit=20)
            return f"analyzed {count} episodes"

    return run_async(_run())


@celery_app.task(bind=True, max_retries=2, default_retry_delay=60)
def generate_report_task(self, kind: str, report_key: str | None = None) -> str:
    """生成一期刊物（kind=daily|weekly|monthly；缺 key 用默认窗口）。"""

    async def _run() -> str:
        from app.domains.insight.report_service import ReportService

        async with worker_session("insight-report") as db:
            report = await ReportService(db).generate_report(kind, report_key, force=True)
            if report is None:
                return f"{kind}/{report_key}: skipped (empty window)"
            return f"{kind}/{report.report_key}: revision={report.revision}"

    return run_async(_run())


@celery_app.task(bind=True, max_retries=1)
def reports_catchup_task(self) -> str:
    """每小时兜底：当日/本周/本月刊物缺失则补刊（cron 漏跑保险）。"""

    async def _run() -> str:
        from app.domains.insight.report_service import ReportService, default_report_key

        results = []
        async with worker_session("insight-catchup") as db:
            service = ReportService(db)
            for kind in ("daily", "weekly", "monthly"):
                key = default_report_key(kind)
                if await service.get_report(kind, key) is None:
                    report = await service.generate_report(kind, key, force=False)
                    results.append(f"{kind}/{key}: {'generated' if report else 'empty-window'}")
                else:
                    results.append(f"{kind}/{key}: exists")
        return "; ".join(results)

    return run_async(_run())
