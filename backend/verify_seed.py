import asyncio
import asyncpg

async def main():
    c = await asyncpg.connect(
        "postgresql://wayn_user:WaynDb_2026_Test!@localhost:5432/wayn_test_db"
    )

    print("=== ROLES ===")
    print(await c.fetch("SELECT id, name FROM roles ORDER BY id"))

    print("=== PERMISSIONS ===")
    print(await c.fetch("SELECT id, name FROM permissions ORDER BY id"))

    print("=== ADMIN ===")
    print(await c.fetch(
        "SELECT id, email, full_name, is_active FROM admin_users"
    ))

    print("=== SUPER ADMIN PERMISSIONS ===")
    print(await c.fetch("""
        SELECT r.name, p.name AS permission
        FROM roles r
        JOIN role_permissions rp ON rp.role_id = r.id
        JOIN permissions p ON p.id = rp.permission_id
        WHERE r.name = 'super_admin'
        ORDER BY p.name
    """))

    print("=== ADMIN ROLES ===")
    print(await c.fetch("""
        SELECT au.email, r.name
        FROM admin_users au
        JOIN admin_user_roles aur
            ON aur.admin_user_id = au.id
        JOIN roles r
            ON r.id = aur.role_id
    """))

    await c.close()

asyncio.run(main())
