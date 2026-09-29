"""Dedicated queue worker entrypoint (replaces the Celery worker + beat pair).

Runs procrastinate's asyncio worker: fetches jobs from Postgres, executes the
registered podcast tasks and defers the periodic (cron) schedules — the old
beat container's job. Cron expressions are evaluated in the process-local
timezone; the compose file pins TZ=UTC on this service to keep parity with
the former Celery beat schedules.

Usage:
    python -m app.bootstrap.worker                # run the worker
    python -m app.bootstrap.worker --healthcheck  # probe queue readiness
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import sys

from app.core.config import get_settings
from app.core.database import close_db, init_db
from app.core.jobs import build_queue_conninfo, procrastinate_app
from app.core.logging_config import setup_logging_from_env


logger = logging.getLogger(__name__)


async def run_worker() -> None:
    settings = get_settings()
    setup_logging_from_env()

    # Import for side effect: registers tasks and periodic schedules.
    import app.domains.podcast.tasks  # noqa: F401

    await init_db()

    # Parity with the old Celery worker_process_init hook: fail transcription
    # tasks orphaned by a crashed worker before consuming new jobs.
    from app.bootstrap.lifecycle import reset_stale_transcription_tasks

    await reset_stale_transcription_tasks()

    logger.info(
        "Starting queue worker (concurrency=%s, connector=psycopg)",
        settings.WORKER_CONCURRENCY,
    )
    try:
        async with procrastinate_app.open_async() as app:
            await app.run_worker_async(concurrency=settings.WORKER_CONCURRENCY)
    finally:
        await close_db()
        logger.info("Queue worker stopped")


async def healthcheck() -> int:
    """Exit 0 when Postgres and the procrastinate schema are reachable."""
    import psycopg

    conninfo = build_queue_conninfo()
    try:
        async with await psycopg.AsyncConnection.connect(conninfo) as conn:
            row = await conn.execute(
                "SELECT EXISTS(SELECT 1 FROM information_schema.tables "
                "WHERE table_name = 'procrastinate_jobs')"
            )
            exists = (await row.fetchone())[0]
        if not exists:
            logger.error("Healthcheck failed: procrastinate_jobs table missing")
            return 1
        return 0
    except Exception:
        logger.exception("Healthcheck failed: cannot reach the queue database")
        return 1


def main() -> None:
    parser = argparse.ArgumentParser(description="Sonde queue worker")
    parser.add_argument(
        "--healthcheck",
        action="store_true",
        help="Verify Postgres and the procrastinate schema, then exit",
    )
    args = parser.parse_args()

    if args.healthcheck:
        sys.exit(asyncio.run(healthcheck()))
    asyncio.run(run_worker())


if __name__ == "__main__":
    main()
