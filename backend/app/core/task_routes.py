from fastapi import APIRouter

from app.core.celery_app import celery_app
from app.domains.podcast.schemas import TaskStatusResponse

router = APIRouter(tags=["tasks"])


@router.get("/tasks/{task_id}", response_model=TaskStatusResponse)
async def get_task_status(task_id: str) -> TaskStatusResponse:
    task = celery_app.AsyncResult(task_id)
    result = task.result if task.ready() and not task.failed() else None
    error = str(task.result) if task.failed() else None
    if not isinstance(result, (dict, list, str, int, float, bool)) and result is not None:
        result = str(result)

    return TaskStatusResponse(
        task_id=task_id,
        status=task.status.lower(),
        result=result,
        error=error,
    )
