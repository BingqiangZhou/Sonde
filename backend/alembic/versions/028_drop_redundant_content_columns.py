"""drop_redundant_content_columns

Revision ID: 028
Revises: 027
Create Date: 2026-08-21 00:00:00.000000

Converges content storage on the canonical stores:
- transcription_tasks.transcript_content / summary_content were copies of
  podcast_episode_transcripts.transcript_content and
  podcast_episodes.ai_summary; reads already come from the canonical
  stores and the engine no longer writes the task-row copies.
- podcast_episodes.summary_version was always the constant "1.0" and was
  never displayed.

Before dropping, task-row copies are backfilled into the canonical stores
for any rows where the canonical store is missing data.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "028"
down_revision: Union[str, Sequence[str], None] = "027"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Backfill: task transcript copies into the dedicated transcript table.
    op.execute(
        """
        INSERT INTO podcast_episode_transcripts
            (episode_id, transcript_content, transcript_word_count)
        SELECT t.episode_id, t.transcript_content, t.transcript_word_count
        FROM transcription_tasks t
        WHERE t.transcript_content IS NOT NULL
        ON CONFLICT (episode_id) DO NOTHING
        """
    )
    # Backfill: task summary copies into episodes missing their summary.
    op.execute(
        """
        UPDATE podcast_episodes e
        SET ai_summary = t.summary_content
        FROM transcription_tasks t
        WHERE t.episode_id = e.id
          AND t.summary_content IS NOT NULL
          AND e.ai_summary IS NULL
        """
    )

    op.drop_column("transcription_tasks", "transcript_content")
    op.drop_column("transcription_tasks", "summary_content")
    op.drop_column("podcast_episodes", "summary_version")


def downgrade() -> None:
    # Columns are restored empty; the canonical stores keep the data.
    op.add_column(
        "transcription_tasks",
        sa.Column("transcript_content", sa.Text(), nullable=True),
    )
    op.add_column(
        "transcription_tasks",
        sa.Column("summary_content", sa.Text(), nullable=True),
    )
    op.add_column(
        "podcast_episodes",
        sa.Column("summary_version", sa.String(length=50), nullable=True),
    )
