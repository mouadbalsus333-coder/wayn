from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies.admin_auth import get_current_admin
from app.core.database import get_session
from app.schemas.admin_dashboard import AdminDashboardSummary
from app.services.admin_dashboard_service import AdminDashboardService


router = APIRouter(
    prefix="/admin/dashboard",
    tags=["Admin Dashboard"],
)


@router.get(
    "/summary",
    response_model=AdminDashboardSummary,
)
async def get_dashboard_summary(
    admin_user=Depends(get_current_admin),
    session: AsyncSession = Depends(get_session),
) -> AdminDashboardSummary:
    return await AdminDashboardService(session).get_summary(admin_user)