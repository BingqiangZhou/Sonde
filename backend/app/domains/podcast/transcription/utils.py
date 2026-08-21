"""Transcription utility functions."""

import asyncio
from typing import Any

import ffmpeg

from .models import AudioChunk


async def _ffmpeg_probe_async(input_path: str) -> dict[str, Any]:
    return await asyncio.to_thread(ffmpeg.probe, input_path)


def build_chunk_info(chunks: list[AudioChunk]) -> dict[str, Any]:
    """Build lightweight persisted metadata for chunk execution state."""
    ordered_chunks = sorted(chunks, key=lambda item: item.index)
    return {
        "total_chunks": len(ordered_chunks),
        "chunks": [
            {
                "index": chunk.index,
                "start_time": chunk.start_time,
                "duration": chunk.duration,
                "status": "completed" if chunk.transcript else "failed",
            }
            for chunk in ordered_chunks
        ],
    }
