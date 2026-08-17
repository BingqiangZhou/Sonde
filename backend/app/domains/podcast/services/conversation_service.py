"""播客对话交互服务
支持基于AI摘要的上下文保持对话
"""

import logging
import time
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import and_, delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.ai_client import AIClientService
from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.ai.services.model_config_service import AIModelSecurityService
from app.domains.podcast.models import (
    ConversationSession,
    PodcastConversation,
    PodcastEpisode,
)


logger = logging.getLogger(__name__)


class ConversationService:
    """播客对话服务"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.ai_model_repo = AIModelConfigRepository(db)
        self._security_service = AIModelSecurityService(db)

    # === Session Management ===

    async def get_sessions(
        self,
        episode_id: int,
        user_id: int,
    ) -> list[dict[str, Any]]:
        """获取某个 episode 的所有对话会话"""
        # Sub-query for message counts
        msg_count_subq = (
            select(
                PodcastConversation.session_id,
                func.count(PodcastConversation.id).label("message_count"),
            )
            .group_by(PodcastConversation.session_id)
            .subquery()
        )

        stmt = (
            select(ConversationSession, msg_count_subq.c.message_count)
            .outerjoin(
                msg_count_subq,
                ConversationSession.id == msg_count_subq.c.session_id,
            )
            .where(
                and_(
                    ConversationSession.episode_id == episode_id,
                    ConversationSession.user_id == user_id,
                ),
            )
            .order_by(ConversationSession.created_at.desc())
        )
        result = await self.db.execute(stmt)
        rows = result.all()

        return [
            {
                "id": session.id,
                "episode_id": session.episode_id,
                "title": session.title,
                "message_count": message_count or 0,
                "created_at": session.created_at,
                "updated_at": session.updated_at,
            }
            for session, message_count in rows
        ]

    async def create_session(
        self,
        episode_id: int,
        user_id: int,
        title: str | None = None,
    ) -> dict[str, Any]:
        """创建新对话会话"""
        # Count existing sessions for auto-naming
        count_stmt = select(func.count(ConversationSession.id)).where(
            and_(
                ConversationSession.episode_id == episode_id,
                ConversationSession.user_id == user_id,
            ),
        )
        count_result = await self.db.execute(count_stmt)
        existing_count = count_result.scalar() or 0

        session = ConversationSession(
            episode_id=episode_id,
            user_id=user_id,
            title=title or f"对话 {existing_count + 1}",
        )
        self.db.add(session)
        await self.db.commit()
        # No refresh needed - session.id is auto-populated by SQLAlchemy after flush/commit

        logger.info(
            f"Created session {session.id} for episode {episode_id}, user {user_id}"
        )
        return {
            "id": session.id,
            "episode_id": session.episode_id,
            "title": session.title,
            "message_count": 0,
            "created_at": session.created_at,
            "updated_at": session.updated_at,
        }

    async def delete_session(
        self,
        session_id: int,
        user_id: int,
    ) -> int:
        """删除对话会话及其所有消息"""
        stmt = select(ConversationSession).where(
            and_(
                ConversationSession.id == session_id,
                ConversationSession.user_id == user_id,
            ),
        )
        result = await self.db.execute(stmt)
        session = result.scalar_one_or_none()
        if not session:
            raise ValidationError(f"Session {session_id} not found")

        # Count messages before deleting
        msg_count_stmt = select(func.count(PodcastConversation.id)).where(
            PodcastConversation.session_id == session_id,
        )
        msg_count_result = await self.db.execute(msg_count_stmt)
        deleted_count = msg_count_result.scalar() or 0

        await self.db.delete(session)  # cascade deletes messages
        await self.db.commit()
        logger.info(f"Deleted session {session_id} with {deleted_count} messages")
        return deleted_count

    async def get_or_create_default_session(
        self,
        episode_id: int,
        user_id: int,
    ) -> int:
        """获取或创建默认会话，返回 session_id"""
        # Try to find the most recent session
        stmt = (
            select(ConversationSession)
            .where(
                and_(
                    ConversationSession.episode_id == episode_id,
                    ConversationSession.user_id == user_id,
                ),
            )
            .order_by(ConversationSession.created_at.desc())
            .limit(1)
        )
        result = await self.db.execute(stmt)
        session = result.scalar_one_or_none()

        if session:
            return session.id

        # Create default session
        new_session = ConversationSession(
            episode_id=episode_id,
            user_id=user_id,
            title="默认对话",
        )
        self.db.add(new_session)
        await self.db.flush()
        return new_session.id

    # === Conversation History ===

    async def get_conversation_history(
        self,
        episode_id: int,
        user_id: int,
        session_id: int | None = None,
        limit: int = 50,
    ) -> list[dict[str, Any]]:
        """获取对话历史（按 session 过滤）"""
        conditions = [
            PodcastConversation.episode_id == episode_id,
            PodcastConversation.user_id == user_id,
        ]
        if session_id is not None:
            conditions.append(PodcastConversation.session_id == session_id)

        stmt = (
            select(PodcastConversation)
            .where(and_(*conditions))
            .order_by(
                PodcastConversation.conversation_turn, PodcastConversation.created_at
            )
            .limit(limit)
        )
        result = await self.db.execute(stmt)
        conversations = result.scalars().all()

        return [
            {
                "id": conv.id,
                "role": conv.role,
                "content": conv.content,
                "conversation_turn": conv.conversation_turn,
                "created_at": conv.created_at.isoformat(),
            }
            for conv in conversations
        ]

    async def send_message(
        self,
        episode_id: int,
        user_id: int,
        user_message: str,
        model_name: str | None = None,
        session_id: int | None = None,
    ) -> dict[str, Any]:
        """发送消息并获取AI回复"""
        # 获取播客单集信息
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if not episode:
            raise ValidationError(f"Episode {episode_id} not found")

        if not episode.ai_summary:
            raise ValidationError(
                "Cannot start conversation: AI summary not available for this episode"
            )

        # Ensure session exists
        if session_id is None:
            session_id = await self.get_or_create_default_session(episode_id, user_id)

        # 获取对话历史（按 session 过滤）
        conversation_history = await self.get_conversation_history(
            episode_id, user_id, session_id=session_id
        )

        # 确定当前对话轮次
        current_turn = len(conversation_history)

        # 保存用户消息
        user_conv = PodcastConversation(
            episode_id=episode_id,
            user_id=user_id,
            session_id=session_id,
            role="user",
            content=user_message,
            conversation_turn=current_turn,
            created_at=datetime.now(UTC),
        )
        self.db.add(user_conv)
        await self.db.flush()  # 获取ID

        # 构建对话上下文
        messages = self._build_conversation_context(
            episode, conversation_history, user_message
        )

        # 调用AI API via unified AIClientService
        start_time = time.time()
        ai_response_content = await self._call_ai_api(messages, model_name)
        processing_time = time.time() - start_time

        # 保存AI回复
        assistant_conv = PodcastConversation(
            episode_id=episode_id,
            user_id=user_id,
            session_id=session_id,
            role="assistant",
            content=ai_response_content,
            parent_message_id=user_conv.id,
            conversation_turn=current_turn + 1,
            processing_time=processing_time,
            created_at=datetime.now(UTC),
        )
        self.db.add(assistant_conv)

        await self.db.commit()
        # No refresh needed - assistant_conv.id is auto-populated by SQLAlchemy after flush/commit

        logger.info(
            f"Conversation saved for episode {episode_id}, user {user_id}, session {session_id}, turn {current_turn + 1}"
        )

        return {
            "id": assistant_conv.id,
            "role": "assistant",
            "content": assistant_conv.content,
            "conversation_turn": assistant_conv.conversation_turn,
            "processing_time": processing_time,
            "created_at": assistant_conv.created_at.isoformat(),
        }

    def _build_conversation_context(
        self,
        episode: PodcastEpisode,
        conversation_history: list[dict[str, Any]],
        user_message: str,
    ) -> list[dict[str, str]]:
        """构建对话上下文"""
        messages = []

        # 系统提示词 - 包含AI摘要作为上下文
        system_prompt = f"""你是一位专业的播客内容分析师和讨论伙伴。用户正在与你讨论一期播客节目的AI总结。

## 播客信息
**标题**: {episode.title}
**描述**: {episode.description or "无"}

## AI总结内容
{episode.ai_summary}

## 对话规则
1. 基于上面的AI总结内容回答用户问题
2. 如果用户询问总结中未涵盖的细节，请诚实地说明总结中未包含该信息
3. 保持回答的准确性和客观性
4. 可以根据总结内容进行合理的推理和分析
5. 回答要简洁明了，直接回应用户的问题
6. 如果需要，可以引用总结中的具体内容
"""

        messages.append({"role": "system", "content": system_prompt})

        # 添加历史对话
        for conv in conversation_history:
            messages.append(
                {
                    "role": conv["role"],
                    "content": conv["content"],
                }
            )

        # 添加当前用户消息
        messages.append(
            {
                "role": "user",
                "content": user_message,
            }
        )

        return messages

    async def _call_ai_api(
        self,
        messages: list[dict[str, str]],
        model_name: str | None = None,
    ) -> str:
        """调用AI API进行对话 (delegates to AIClientService).

        按优先级获取模型配置，实现fallback机制。
        """
        ai_client = AIClientService(
            repo=self.ai_model_repo,
            security_service=self._security_service,
        )

        content, _model = await ai_client.call_with_fallback(
            messages,
            model_type=ModelType.TEXT_GENERATION,
            model_name=model_name,
            operation_name="Conversation",
        )
        return content

    async def clear_conversation_history(
        self,
        episode_id: int,
        user_id: int,
        session_id: int | None = None,
    ) -> int:
        """清除对话历史（按 session 过滤）"""
        conditions = [
            PodcastConversation.episode_id == episode_id,
            PodcastConversation.user_id == user_id,
        ]
        if session_id is not None:
            conditions.append(PodcastConversation.session_id == session_id)

        stmt = delete(PodcastConversation).where(and_(*conditions))
        result = await self.db.execute(stmt)
        count = int(result.rowcount or 0)

        await self.db.commit()
        logger.info(
            f"Cleared {count} conversation messages for episode {episode_id}, user {user_id}, session {session_id}"
        )

        return count
