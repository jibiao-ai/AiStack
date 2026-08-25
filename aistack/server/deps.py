from typing import Annotated
from fastapi import Depends
from sqlmodel.ext.asyncio.session import AsyncSession
from aistack.schemas.users import User
from aistack.api.auth import get_admin_user, get_current_user
from aistack.api.tenant import (
    TenantContext,
    get_tenant_context,
    require_platform_admin,
)
from aistack.server.db import get_session
from aistack.schemas.common import ListParams

SessionDep = Annotated[AsyncSession, Depends(get_session)]
ListParamsDep = Annotated[ListParams, Depends(ListParams)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]
CurrentAdminUserDep = Annotated[User, Depends(get_admin_user)]
TenantContextDep = Annotated[TenantContext, Depends(get_tenant_context)]
PlatformAdminDep = Annotated[TenantContext, Depends(require_platform_admin)]
