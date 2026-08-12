import asyncio
import asyncpg
from app.core.config import settings

url = settings.database_url.replace("postgresql+asyncpg://", "postgresql://", 1)

async def check():
    conn = await asyncpg.connect(url)
    # Alembic version
    v = await conn.fetchval("SELECT version_num FROM alembic_version")
    print("ALEMBIC VERSION:", v)
    # Enum values
    enums = await conn.fetch(
        "SELECT enumlabel FROM pg_enum "
        "WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'account_status') "
        "ORDER BY enumsortorder"
    )
    print("ENUM VALUES:", [r["enumlabel"] for r in enums])
    # Columns on users
    cols = await conn.fetch(
        "SELECT column_name, data_type, is_nullable, column_default "
        "FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position"
    )
    for c in cols:
        print(f"  {c['column_name']:25s} {c['data_type']:20s} nullable={c['is_nullable']:3s} default={c['column_default']}")
    # Existing test user
    u = await conn.fetchrow(
        "SELECT id, email, token_version, account_status, is_active, is_verified "
        "FROM users WHERE email = 'wayntest@gmail.com'"
    )
    print("TEST USER:", dict(u) if u else "NOT FOUND")
    # Admin users
    admins = await conn.fetch("SELECT id, email, is_active FROM admin_users")
    print("ADMIN USERS:", [dict(a) for a in admins])
    # Roles
    roles = await conn.fetch("SELECT id, name FROM roles ORDER BY id")
    print("ROLES:", [dict(r) for r in roles])
    # Permissions
    perms = await conn.fetch("SELECT id, name FROM permissions ORDER BY id")
    print("PERMISSIONS:", [dict(p) for p in perms])
    # Admin user roles
    aur = await conn.fetch(
        "SELECT aur.admin_user_id, aur.role_id, r.name as role_name "
        "FROM admin_user_roles aur JOIN roles r ON r.id = aur.role_id"
    )
    print("ADMIN USER ROLES:", [dict(r) for r in aur])
    # Role permissions
    rp = await conn.fetch(
        "SELECT rp.role_id, rp.permission_id, p.name as perm_name "
        "FROM role_permissions rp JOIN permissions p ON p.id = rp.permission_id"
    )
    print("ROLE PERMISSIONS:", [dict(p) for p in rp])
    await conn.close()

asyncio.run(check())
