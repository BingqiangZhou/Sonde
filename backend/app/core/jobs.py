"""Procrastinate job queue core — Postgres-backed task queue.

Replaces the former Celery+Redis pair: jobs, retries and cron schedules all
live in Postgres (see docs/INFRA_PGQUEUE_CADDY_2026-09-29.md). The connector
uses psycopg with its own small pool, independent of the SQLAlchemy/asyncpg
engine that serves normal request traffic.

Task modules register themselves on ``procrastinate_app`` via the
``@procrastinate_app.task`` decorator at import time; both the API process
(enqueue side) and ``app.bootstrap.worker`` (consume side) import them.
"""

from __future__ import annotations

from procrastinate import App, PsycopgConnector
from procrastinate.jobs import Job
from procrastinate.retry import RetryDecision, RetryStrategy

from app.core.config import get_settings


def build_queue_conninfo() -> str:
    """Derive the psycopg DSN from the SQLAlchemy DATABASE_URL."""
    dsn = get_settings().require_database_url()
    for driver in ("postgresql+asyncpg://", "postgresql+psycopg://"):
        if dsn.startswith(driver):
            return "postgresql://" + dsn[len(driver) :]
    return dsn


class ExponentialBackoffRetry(RetryStrategy):
    """Exponential backoff matching the former Celery countdown (60 * 2**n)."""

    def get_retry_decision(
        self,
        *,
        exception: BaseException,
        job: Job,
    ) -> RetryDecision | None:
        if self.max_attempts and job.attempts >= self.max_attempts:
            return None
        if self.retry_exceptions and not isinstance(
            exception,
            tuple(self.retry_exceptions),
        ):
            return None
        # job.attempts is 1 while the first execution is running.
        return RetryDecision(retry_in={"seconds": 60 * 2 ** max(0, job.attempts - 1)})


def exponential_retry(*, max_attempts: int) -> ExponentialBackoffRetry:
    """Retry policy matching the old Celery tasks (max_retries=3 → 4 runs)."""
    return ExponentialBackoffRetry(max_attempts=max_attempts)


procrastinate_app = App(
    connector=PsycopgConnector(conninfo=build_queue_conninfo()),
)


__all__ = [
    "ExponentialBackoffRetry",
    "build_queue_conninfo",
    "exponential_retry",
    "procrastinate_app",
]
