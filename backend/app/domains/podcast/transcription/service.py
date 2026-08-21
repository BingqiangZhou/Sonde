"""Podcast transcription service - orchestrates the full transcription pipeline."""

import asyncio
import logging
import os
import re
import time
from datetime import UTC, datetime
from typing import Any

import aiofiles
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ValidationError
from app.domains.ai.key_resolver import extract_model_key
from app.domains.ai.model_resolution import resolve_active_model_config
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionStatus,
    TranscriptionStep,
    TranscriptionTask,
)

from .converter import AudioConverter
from .downloader import AudioDownloader
from .models import AudioChunk
from .splitter import AudioSplitter
from .transcriber import SiliconFlowTranscriber
from .utils import _ffmpeg_probe_async, build_chunk_info


logger = logging.getLogger(__name__)


class PodcastTranscriptionService:
    """Pipeline engine: download, convert, split, transcribe and persist.

    Every step checks for artifacts left by an interrupted run and resumes
    from them; temp files are only removed after the task completes.
    """

    def __init__(self, db: AsyncSession):
        self.db = db
        self._progress_cache: dict[str, dict[str, float | str]] = {}
        self._task_progress_context_cache: dict[int, dict[str, Any]] = {}

        # Get path from settings - use absolute path if configured, otherwise resolve relative path
        temp_dir_config = getattr(
            settings,
            "TRANSCRIPTION_TEMP_DIR",
            "./temp/transcription",
        )
        storage_dir_config = getattr(
            settings,
            "TRANSCRIPTION_STORAGE_DIR",
            "./storage/podcasts",
        )

        # Use configured path directly (supports both absolute and relative)
        # In Docker, these will be absolute paths like /app/temp/transcription
        # In local dev, these will be relative paths that get resolved
        self.temp_dir = os.path.abspath(temp_dir_config)
        self.storage_dir = os.path.abspath(storage_dir_config)

        # Log for debugging (use debug level to reduce noise)
        logger.debug(
            f"[TRANSCRIPTION] temp_dir = {self.temp_dir} (from config: {temp_dir_config})",
        )
        logger.debug(
            f"[TRANSCRIPTION] storage_dir = {self.storage_dir} (from config: {storage_dir_config})",
        )
        logger.debug(f"[TRANSCRIPTION] cwd = {os.getcwd()}")

        self.chunk_size_mb = getattr(settings, "TRANSCRIPTION_CHUNK_SIZE_MB", 10)
        self.max_threads = getattr(settings, "TRANSCRIPTION_MAX_THREADS", 4)
        self.min_chunk_success_ratio = float(
            getattr(settings, "TRANSCRIPTION_MIN_CHUNK_SUCCESS_RATIO", 0.6),
        )
        self.progress_commit_min_delta = float(
            getattr(settings, "TRANSCRIPTION_PROGRESS_COMMIT_MIN_DELTA", 5.0),
        )
        self.progress_commit_min_interval = float(
            getattr(
                settings, "TRANSCRIPTION_PROGRESS_COMMIT_MIN_INTERVAL_SECONDS", 3.0
            ),
        )
        # API configuration is now dynamic, but we keep defaults for fallback
        self.default_api_url = getattr(
            settings,
            "TRANSCRIPTION_API_URL",
            "https://api.siliconflow.cn/v1/audio/transcriptions",
        )

    def _get_episode_storage_path(self, episode: PodcastEpisode) -> str:
        """Build the storage path for an episode's transcription files."""
        podcast_name = self._sanitize_filename(episode.subscription.title)
        episode_name = self._sanitize_filename(episode.title)

        return os.path.join(self.storage_dir, podcast_name, episode_name)

    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename by removing invalid characters and truncating length."""
        filename = re.sub(r'[<>:"/\\|?*]', "", filename)
        filename = filename.replace(" ", "_")
        return filename[:100]

    async def _update_task_progress_with_session(
        self,
        session: AsyncSession,
        task_id: int,
        step: TranscriptionStep,
        progress: float,
        message: str,
        error_message: str | None = None,
    ):
        """Persist step/progress with write throttling.

        DB writes are skipped until the progress delta or the minimum
        interval is exceeded (100% always writes). The first write flips
        the task to IN_PROGRESS and stamps started_at; changed messages
        are folded into chunk_info.debug_message.
        """
        cache_key = f"{task_id}_{step}"
        if cache_key not in self._progress_cache:
            self._progress_cache[cache_key] = {
                "last_db_update": 0.0,
                "last_db_update_at": 0.0,
                "last_log": 0.0,
            }

        cached = self._progress_cache[cache_key]
        progress_delta = abs(progress - cached["last_db_update"])
        now_mono = time.monotonic()
        last_db_update_at = float(cached.get("last_db_update_at", 0.0))
        interval_elapsed = now_mono - last_db_update_at

        if (
            progress_delta < self.progress_commit_min_delta
            and interval_elapsed < self.progress_commit_min_interval
            and int(progress) != 100
        ):
            return

        update_data = {
            "current_step": step,
            "progress_percentage": progress,
            "updated_at": datetime.now(UTC),
        }

        if error_message:
            update_data["error_message"] = error_message

        context = self._task_progress_context_cache.get(task_id)
        if context is None:
            stmt_context = select(
                TranscriptionTask.started_at,
                TranscriptionTask.chunk_info,
            ).where(TranscriptionTask.id == task_id)
            context_row = (await session.execute(stmt_context)).one_or_none()
            started_at = context_row[0] if context_row else None
            chunk_info = context_row[1] if context_row else None
            context = {
                "started": bool(started_at),
                "chunk_info": chunk_info if isinstance(chunk_info, dict) else {},
                "last_debug_message": (
                    chunk_info.get("debug_message")
                    if isinstance(chunk_info, dict)
                    else None
                ),
            }
            self._task_progress_context_cache[task_id] = context

        if not context["started"]:
            update_data["started_at"] = datetime.now(UTC)
            update_data["status"] = TranscriptionStatus.IN_PROGRESS
            context["started"] = True

        if message and message != context.get("last_debug_message"):
            next_chunk_info = dict(context.get("chunk_info") or {})
            next_chunk_info["debug_message"] = message
            update_data["chunk_info"] = next_chunk_info
            context["chunk_info"] = next_chunk_info
            context["last_debug_message"] = message

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await session.execute(stmt)
        await session.commit()

        cached["last_db_update"] = progress
        cached["last_db_update_at"] = now_mono

        log_delta = abs(progress - cached["last_log"])
        if log_delta >= 5.0 or int(progress) == 100:
            if int(progress) == 100:
                logger.info("[PROGRESS] Task %s: %s - COMPLETED", task_id, step)
            else:
                logger.info("[PROGRESS] Task %s: %s - %.1f%%", task_id, step, progress)
            cached["last_log"] = progress

    async def _set_task_final_status(
        self,
        session: AsyncSession,
        task_id: int,
        status: TranscriptionStatus,
        error_message: str | None = None,
    ):
        """Write the terminal status and clear per-task progress caches."""
        update_data = {"status": status, "updated_at": datetime.now(UTC)}

        if status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            update_data["completed_at"] = datetime.now(UTC)

        if error_message:
            update_data["error_message"] = error_message

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await session.execute(stmt)
        await session.commit()

        self._task_progress_context_cache.pop(task_id, None)
        for progress_key in [
            key for key in self._progress_cache if key.startswith(f"{task_id}_")
        ]:
            self._progress_cache.pop(progress_key, None)

        logger.info(f"Set task {task_id} final status: {status}")

    async def create_transcription_task_record(
        self,
        episode_id: int,
        model: str | None = None,
        force: bool = False,
    ) -> tuple[TranscriptionTask, int | None]:
        """Create (or replace) the task row for an episode.

        An existing non-failed task blocks creation unless force=True;
        failed/cancelled tasks are deleted first so the unique episode
        constraint is released.

        Returns:
            The new task and the resolved model config DB id.
        """
        logger.info(
            f"[TRANSCRIPTION PREPARE] episode_id={episode_id}, model={model}, force={force}",
        )

        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id,
        )
        result = await self.db.execute(stmt)
        existing_task = result.scalar_one_or_none()

        if existing_task:
            logger.info(
                f"[TRANSCRIPTION] Existing task found: id={existing_task.id}, status={existing_task.status}",
            )
            if force:
                # Force mode: delete existing task and create new one (regardless of status)
                logger.info(
                    f"[TRANSCRIPTION] Force mode: deleting existing task {existing_task.id}",
                )
                await self.db.delete(existing_task)
                await self.db.flush()
                await (
                    self.db.commit()
                )  # Commit the delete to release the unique constraint
            elif existing_task.status not in [
                TranscriptionStatus.FAILED,
                TranscriptionStatus.CANCELLED,
            ]:
                # Task exists with non-failed/cancelled status and force=false: raise error
                logger.warning(
                    f"[TRANSCRIPTION] Task already exists with status {existing_task.status}",
                )
                raise ValidationError(
                    f"Transcription task already exists for episode {episode_id} with status {existing_task.status}. Use force=true to retry.",
                )
            else:
                # Task exists with failed/cancelled status and force=false: delete it and create new one
                logger.info(
                    f"[TRANSCRIPTION] Removing failed/cancelled task {existing_task.id} before creating new one",
                )
                await self.db.delete(existing_task)
                await self.db.flush()
                await (
                    self.db.commit()
                )  # Commit the delete to release the unique constraint
                logger.info(
                    "[TRANSCRIPTION] Failed/cancelled task removed, ready to create new one",
                )

        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if not episode:
            logger.error(f"[TRANSCRIPTION] Episode {episode_id} not found")
            raise ValidationError(f"Episode {episode_id} not found")

        logger.info(
            f"[TRANSCRIPTION] Episode found: title='{episode.title}', audio_url='{episode.audio_url}'",
        )

        # Resolve the transcription model by name (validated) or priority.
        model_config = await resolve_active_model_config(
            AIModelConfigRepository(self.db),
            model_type=ModelType.TRANSCRIPTION,
            model_name=model,
            operation_name="Transcription",
        )
        logger.info(
            f"[TRANSCRIPTION] Using model: {model_config.model_id} "
            f"(priority={model_config.priority})",
        )

        transcription_model = model_config.model_id

        logger.info("[TRANSCRIPTION] Creating TranscriptionTask in database...")
        task = TranscriptionTask(
            episode_id=episode_id,
            original_audio_url=episode.audio_url,
            chunk_size_mb=self.chunk_size_mb,
            model_used=transcription_model,  # Provider model id, e.g. whisper-1
        )

        self.db.add(task)
        await self.db.commit()
        # No refresh needed - task.id is auto-populated by SQLAlchemy after flush/commit

        logger.info(
            f"[TRANSCRIPTION] Task created in DB: id={task.id}, status={task.status}",
        )

        config_db_id = model_config.id
        return task, config_db_id

    async def execute_transcription_task(
        self,
        task_id: int,
        session,
        config_db_id: int | None = None,
    ):
        """Run the pipeline for one task, resuming from existing artifacts."""
        task: TranscriptionTask | None = None
        try:
            ai_repo = AIModelConfigRepository(session)
            stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
            result = await session.execute(stmt)
            task = result.scalar_one_or_none()

            if not task:
                raise RuntimeError(f"Transcription task {task_id} not found")

            if task.status == TranscriptionStatus.COMPLETED:
                logger.info(
                    "[SKIP] Task %s already completed (%s words)",
                    task_id,
                    task.transcript_word_count or 0,
                )
                return

            if task.status == TranscriptionStatus.CANCELLED:
                logger.warning("[SKIP] Task %s was cancelled", task_id)
                return

            # selectinload: the storage path needs episode.subscription.title
            from sqlalchemy.orm import selectinload

            stmt = (
                select(PodcastEpisode)
                .options(selectinload(PodcastEpisode.subscription))
                .where(PodcastEpisode.id == task.episode_id)
            )
            result = await session.execute(stmt)
            episode = result.scalar_one_or_none()

            if not episode:
                logger.error(
                    "Episode %s not found for task %s", task.episode_id, task_id
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Episode not found",
                )
                raise RuntimeError(f"Episode {task.episode_id} not found")

            api_url = self.default_api_url
            api_key = None

            if config_db_id:
                model_config = await ai_repo.get_by_id(config_db_id)
                if model_config and model_config.is_active:
                    api_url = model_config.api_url
                    # Stored keys (possibly encrypted) resolve through the
                    # shared resolver.
                    api_key = extract_model_key(model_config) or model_config.api_key

            if not api_key:
                logger.error("Transcription API key missing for task %s", task_id)
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Transcription API Key not found",
                )
                raise RuntimeError("Transcription API key not found")

            temp_episode_dir = os.path.join(self.temp_dir, f"episode_{task.episode_id}")
            os.makedirs(temp_episode_dir, exist_ok=True)
            logger.info(
                "[EXECUTE] Task %s starting (config_db_id=%s, resume_step=%s)",
                task_id,
                config_db_id,
                task.current_step,
            )

            # === 1/6 Download ===
            download_start = time.time()
            download_time = 0
            original_file = os.path.join(
                temp_episode_dir,
                f"original{os.path.splitext(task.original_audio_url)[-1]}",
            )
            file_size = 0

            if os.path.exists(original_file) and os.path.getsize(original_file) > 0:
                file_size = os.path.getsize(original_file)
                logger.info(
                    "[STEP 1/6 DOWNLOAD] Reusing existing file (%.2f MB)",
                    file_size / 1024 / 1024,
                )
            else:
                logger.info(
                    "[STEP 1/6 DOWNLOAD] Downloading %s...",
                    task.original_audio_url[:100],
                )
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "downloading",
                    5,
                    "Downloading audio file...",
                )

                async with AudioDownloader() as downloader:

                    async def download_progress(progress):
                        await self._update_task_progress_with_session(
                            session,
                            task_id,
                            "downloading",
                            5 + (progress * 0.15),  # 5-20%
                            f"Downloading... {progress:.1f}%",
                        )

                    file_path, file_size = await downloader.download_file_with_fallback(
                        task.original_audio_url,
                        original_file,
                        download_progress,
                    )

                download_time = time.time() - download_start
                logger.info(
                    "[STEP 1/6 DOWNLOAD] Complete: %.2f MB in %.2fs",
                    file_size / 1024 / 1024,
                    download_time,
                )

            file_path = original_file

            # === 2/6 Convert to MP3 ===
            conversion_time = 0
            converted_file = os.path.join(temp_episode_dir, "converted.mp3")

            skip_conversion = False
            if os.path.exists(converted_file):
                converted_size = os.path.getsize(converted_file)
                if converted_size > 10240:  # ignore tiny leftover files
                    try:
                        probe = await _ffmpeg_probe_async(converted_file)
                        duration = (
                            probe.get("format", {}).get("duration") if probe else None
                        )
                        if duration:
                            skip_conversion = True
                            logger.info(
                                "[STEP 2/6 CONVERT] Reusing valid MP3 (%.2f MB, %ss)",
                                converted_size / 1024 / 1024,
                                duration,
                            )
                        else:
                            logger.warning(
                                "[STEP 2/6 CONVERT] Existing file has no duration, "
                                "re-converting"
                            )
                    except Exception as e:
                        logger.warning(
                            "[STEP 2/6 CONVERT] Existing file failed validation "
                            "(%s), re-converting",
                            e,
                        )
                else:
                    logger.warning(
                        "[STEP 2/6 CONVERT] Existing file too small (%s bytes), "
                        "re-converting",
                        converted_size,
                    )

            if not skip_conversion:
                logger.info("[STEP 2/6 CONVERT] Converting to MP3...")
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "converting",
                    20,
                    "Converting to MP3...",
                )

                async def convert_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "converting",
                        20 + (progress * 0.15),  # 20-35%
                        f"Converting... {progress:.1f}%",
                    )

                _, conversion_time = await AudioConverter.convert_to_mp3(
                    file_path,
                    converted_file,
                    convert_progress,
                )

                # Verify the converted file was actually created
                if not os.path.exists(converted_file):
                    logger.error(
                        "[STEP 2/6 CONVERT] Output missing after conversion: %s "
                        "(input exists: %s)",
                        converted_file,
                        os.path.exists(file_path),
                    )
                    await self._set_task_final_status(
                        session,
                        task_id,
                        TranscriptionStatus.FAILED,
                        "MP3 conversion failed - output file not created",
                    )
                    raise RuntimeError(
                        "MP3 conversion failed - output file not created",
                    )

                logger.info(
                    "[STEP 2/6 CONVERT] Complete: %.2f MB in %.2fs",
                    os.path.getsize(converted_file) / 1024 / 1024,
                    conversion_time,
                )

            # === 3/6 Split ===
            if not os.path.exists(converted_file):
                logger.error(
                    "[STEP 3/6 SPLIT] Converted file missing: %s", converted_file
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Converted audio file missing, cannot split",
                )
                raise RuntimeError("Converted audio file missing, cannot split")

            if os.path.getsize(converted_file) == 0:
                logger.error(
                    "[STEP 3/6 SPLIT] Converted file is empty: %s", converted_file
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Converted audio file is empty, cannot split",
                )
                raise RuntimeError("Converted audio file is empty, cannot split")

            split_dir = os.path.join(temp_episode_dir, "chunks")
            chunk_file_pattern = re.compile(r".+_chunk_(\d+)\.mp3$")
            existing_chunks: list[tuple[int, str]] = []
            if os.path.isdir(split_dir):
                for file_name in os.listdir(split_dir):
                    match = chunk_file_pattern.fullmatch(file_name)
                    if match:
                        existing_chunks.append((int(match.group(1)), file_name))

            if existing_chunks:
                # Resumed chunks carry no timing offsets; only file order
                # matters for merging.
                chunks = [
                    AudioChunk(
                        index=index,
                        file_path=os.path.join(split_dir, chunk_file),
                        start_time=0,
                        duration=0,
                        file_size=os.path.getsize(os.path.join(split_dir, chunk_file)),
                        transcript=None,
                    )
                    for index, chunk_file in sorted(
                        existing_chunks, key=lambda item: item[0]
                    )
                ]
                logger.info("[STEP 3/6 SPLIT] Reusing %d existing chunks", len(chunks))
            else:
                logger.info(
                    "[STEP 3/6 SPLIT] Splitting into %dMB chunks...",
                    task.chunk_size_mb,
                )
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "splitting",
                    35,
                    "Splitting audio file...",
                )

                async def split_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "splitting",
                        35 + (progress * 0.10),  # 35-45%
                        f"Splitting... {progress:.1f}%",
                    )

                chunks = await AudioSplitter.split_mp3(
                    converted_file,
                    split_dir,
                    task.chunk_size_mb,
                    split_progress,
                )
                logger.info("[STEP 3/6 SPLIT] Created %d chunks", len(chunks))

            # === 4/6 Transcribe ===
            chunks_to_transcribe = []
            already_transcribed = []
            for chunk in chunks:
                transcript_file = chunk.file_path.replace(".mp3", ".txt")
                if (
                    os.path.exists(transcript_file)
                    and os.path.getsize(transcript_file) > 0
                ):
                    async with aiofiles.open(transcript_file, encoding="utf-8") as f:
                        content = await f.read()
                    if content.strip():
                        chunk.transcript = content
                        already_transcribed.append(chunk)
                        continue
                chunks_to_transcribe.append(chunk)

            logger.info(
                "[STEP 4/6 TRANSCRIBE] %d chunks to transcribe, %d already done "
                "(model=%s)",
                len(chunks_to_transcribe),
                len(already_transcribed),
                task.model_used,
            )

            if chunks_to_transcribe:
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "transcribing",
                    45,
                    f"Transcribing {len(chunks_to_transcribe)} audio chunks...",
                )

                transcription_start = time.time()

                async def transcribe_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "transcribing",
                        45 + (progress * 0.50),  # 45-95%
                        f"Transcribing... {progress:.1f}%",
                    )

                async with SiliconFlowTranscriber(
                    api_key,
                    api_url,
                    self.max_threads,
                ) as transcriber:
                    transcribed_chunks = await transcriber.transcribe_chunks(
                        chunks_to_transcribe,
                        task.model_used,
                        transcribe_progress,
                        ai_repo=ai_repo,
                        config_db_id=config_db_id,
                    )

                all_chunks = already_transcribed + transcribed_chunks

                success_count = sum(1 for c in all_chunks if c.transcript)
                failed_count = len(all_chunks) - success_count
                transcription_time = time.time() - transcription_start
                logger.info(
                    "[STEP 4/6 TRANSCRIBE] %d/%d chunks succeeded in %.2fs",
                    success_count,
                    len(all_chunks),
                    transcription_time,
                )
            else:
                all_chunks = already_transcribed
                logger.info("[STEP 4/6 TRANSCRIBE] All chunks already transcribed")
                success_count = len(all_chunks)
                failed_count = 0
                transcription_time = 0

            total_chunks = len(all_chunks)
            success_ratio = (success_count / total_chunks) if total_chunks else 0.0
            if success_count == 0 or success_ratio < self.min_chunk_success_ratio:
                threshold = self.min_chunk_success_ratio
                error_message = (
                    "Insufficient successful chunks for transcript merge: "
                    f"success={success_count}, failed={failed_count}, "
                    f"total={total_chunks}, ratio={success_ratio:.2f}, "
                    f"required_ratio={threshold:.2f}"
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    error_message,
                )
                raise RuntimeError(error_message)

            # === 5/6 Merge ===
            await self._update_task_progress_with_session(
                session,
                task_id,
                "merging",
                95,
                "Merging transcription results...",
            )

            sorted_chunks = sorted(all_chunks, key=lambda x: x.index)
            full_transcript = "\n\n".join(
                chunk.transcript.strip()
                for chunk in sorted_chunks
                if chunk.transcript and chunk.transcript.strip()
            )
            logger.info(
                "[STEP 5/6 MERGE] Transcript: %d chars, %d words",
                len(full_transcript),
                len(full_transcript.split()),
            )

            # === 6/6 Persist ===
            storage_path = self._get_episode_storage_path(episode)
            os.makedirs(storage_path, exist_ok=True)

            final_audio_path = os.path.join(storage_path, "original.mp3")

            if not os.path.exists(converted_file):
                logger.error(
                    "[STEP 6/6 SAVE] Converted file vanished before persist: %s "
                    "(temp dir files: %s)",
                    converted_file,
                    os.listdir(temp_episode_dir)
                    if os.path.isdir(temp_episode_dir)
                    else None,
                )
                raise FileNotFoundError(
                    f"Converted audio file not found: {converted_file}"
                )

            # Move audio to permanent storage; shutil.move handles
            # cross-device moves (e.g. Docker volumes).
            import shutil

            try:
                await asyncio.to_thread(shutil.move, converted_file, final_audio_path)
            except OSError as e:
                logger.warning(
                    "[STEP 6/6 SAVE] move failed (%s), falling back to copy + delete",
                    e,
                )
                await asyncio.to_thread(shutil.copy2, converted_file, final_audio_path)
                try:
                    await asyncio.to_thread(os.remove, converted_file)
                except OSError:
                    logger.warning(
                        "[STEP 6/6 SAVE] Could not remove source file: %s",
                        converted_file,
                    )

            transcript_path = os.path.join(storage_path, "transcript.txt")
            async with aiofiles.open(transcript_path, "w", encoding="utf-8") as f:
                await f.write(full_transcript)

            task_update = {
                "status": TranscriptionStatus.COMPLETED,
                "current_step": "merging",
                "progress_percentage": 100.0,
                "transcript_word_count": len(full_transcript.split()),
                "original_file_path": final_audio_path,
                "original_file_size": file_size,
                "download_time": download_time,
                "conversion_time": conversion_time,
                "transcription_time": transcription_time,
                "chunk_info": build_chunk_info(sorted_chunks),
                "completed_at": datetime.now(UTC),
            }

            stmt = (
                update(TranscriptionTask)
                .where(TranscriptionTask.id == task_id)
                .values(**task_update)
            )
            await session.execute(stmt)

            # Create or update the dedicated transcript record
            transcript_stmt = select(PodcastEpisodeTranscript).where(
                PodcastEpisodeTranscript.episode_id == task.episode_id
            )
            transcript_row_result = await session.execute(transcript_stmt)
            transcript_row = transcript_row_result.scalar_one_or_none()
            word_count = len(full_transcript.split())
            if transcript_row:
                transcript_row.transcript_content = full_transcript
                transcript_row.transcript_word_count = word_count
            else:
                session.add(
                    PodcastEpisodeTranscript(
                        episode_id=task.episode_id,
                        transcript_content=full_transcript,
                        transcript_word_count=word_count,
                    )
                )

            episode_update = {
                "transcript_url": f"file://{transcript_path}",
                "status": "pending_summary",
            }

            stmt = (
                update(PodcastEpisode)
                .where(PodcastEpisode.id == task.episode_id)
                .values(**episode_update)
            )
            await session.execute(stmt)

            await session.commit()

            logger.info(
                "[TRANSCRIPTION COMPLETE] episode=%s words=%d total=%.2fs "
                "(download=%.2fs convert=%.2fs transcribe=%.2fs)",
                task.episode_id,
                len(full_transcript.split()),
                time.time() - download_start,
                download_time,
                conversion_time,
                transcription_time,
            )

            # Summary generation runs in its own Celery task so the
            # transcription task is not extended by LLM latency; the periodic
            # pending-summary sweeper picks the episode up if enqueueing fails.
            try:
                from app.domains.podcast.tasks.tasks_summary import (
                    generate_episode_summary,
                )

                generate_episode_summary.delay(task.episode_id)
            except Exception as enqueue_error:
                logger.warning(
                    "[AI SUMMARY] Failed to enqueue summary task for episode %s "
                    "(periodic sweeper will retry): %s",
                    task.episode_id,
                    enqueue_error,
                )
        except Exception as e:
            logger.exception("Transcription failed for task %s", task_id)
            status_stmt = select(TranscriptionTask.status).where(
                TranscriptionTask.id == task_id,
            )
            status_result = await session.execute(status_stmt)
            current_status = status_result.scalar()
            if current_status not in {
                TranscriptionStatus.COMPLETED,
                TranscriptionStatus.FAILED,
                TranscriptionStatus.CANCELLED,
                "completed",
                "failed",
                "cancelled",
            }:
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    f"Transcription failed: {e!s}",
                )
            raise
        finally:
            # Only completed tasks clean up temp files; failed or interrupted
            # runs keep them for incremental recovery.
            try:
                stmt_check = select(TranscriptionTask.status).where(
                    TranscriptionTask.id == task_id,
                )
                result_check = await session.execute(stmt_check)
                final_status = result_check.scalar()

                if task is not None:
                    temp_episode_dir = os.path.join(
                        self.temp_dir,
                        f"episode_{task.episode_id}",
                    )
                    if final_status == TranscriptionStatus.COMPLETED:
                        import shutil

                        if os.path.exists(temp_episode_dir):
                            shutil.rmtree(temp_episode_dir)
                            logger.info(
                                "[CLEANUP] Removed temp dir for task %s", task_id
                            )
                    elif os.path.exists(temp_episode_dir):
                        logger.info(
                            "[CLEANUP] Preserved temp dir for task %s (status=%s)",
                            task_id,
                            final_status,
                        )
            except Exception as e:
                logger.error("[CLEANUP] Error during cleanup: %s", e)

    async def get_transcription_status(self, task_id: int) -> TranscriptionTask | None:
        """Load one task row by id."""
        stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_episode_transcription(
        self,
        episode_id: int,
    ) -> TranscriptionTask | None:
        """Load the task row for one episode."""
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id,
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def cancel_transcription(self, task_id: int) -> bool:
        """Mark an active task cancelled; the worker skips it on next check."""
        task = await self.get_transcription_status(task_id)
        if not task:
            return False

        if task.status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            return False

        now = datetime.now(UTC)
        await self.db.execute(
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(
                status=TranscriptionStatus.CANCELLED,
                progress_percentage=task.progress_percentage,
                updated_at=now,
                completed_at=now,
            ),
        )
        await self.db.commit()
        logger.info("Cancelled transcription task %s by user request", task_id)
        return True
