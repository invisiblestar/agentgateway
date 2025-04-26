from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from ..services.openai_service import openai_service

router = APIRouter()

class QueryRequest(BaseModel):
    query: str
    assistant_id: Optional[str] = None
    thread_id: Optional[str] = None


@router.post("/query")
async def process_query(request: QueryRequest):
    """
    Process a query using the specified assistant
    """
    try:
        result = await openai_service.process_query(
            query=request.query,
            assistant_id=request.assistant_id,
            thread_id=request.thread_id
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
