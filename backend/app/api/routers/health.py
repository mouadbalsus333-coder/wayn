from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session

router = APIRouter()


@router.get('/health')
async def health_check():
    return {'status': 'ok'}


@router.get('/health/db')
async def database_health_check(session: AsyncSession = Depends(get_session)):
    try:
        await session.execute(text('SELECT 1'))
        return {'status': 'ok', 'database': 'connected'}
    except Exception as exc:
        return JSONResponse(
            status_code=503,
            content={'status': 'error', 'database': 'disconnected', 'detail': str(exc)},
        )
