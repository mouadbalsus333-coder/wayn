/**
 * Types for the Admin Users module, mirroring the real backend schemas
 * (`backend/app/schemas/admin_user.py` and `backend/app/schemas/pagination.py`).
 */

/** Response of `GET/PUT /api/v1/admin/users/{id}` and `POST /api/v1/admin/users`. */
export type AdminUserRead = {
  id: number
  email: string
  full_name: string
  is_active: boolean
  /** Active role names (backend `AdminUserRead.roles`). */
  roles: string[]
  /** Resolved permission names (roles + direct permissions). */
  permissions: string[]
}

export type AdminUserListParams = {
  page: number
  limit: number
  search?: string | null
  is_active?: boolean | null
  role?: string | null
}

/** `RoleRead` — backend `app/schemas/role.py`. Response of the user-roles endpoints. */
export type RoleRead = {
  id: number
  name: string
  description: string | null
  is_active: boolean
}

/** `AdminUserPermissionRead` — backend `app/schemas/admin_user_permission.py`. */
export type AdminUserPermissionRead = {
  id: number
  name: string
  description: string | null
}

/** `PermissionRead` — backend `app/schemas/permission.py` (the full catalog). */
export type PermissionCatalogItem = {
  id: number
  name: string
  description: string | null
  created_at: string
}

/** Body of `PUT /admin/users/{id}/roles` (`AdminUserRoleUpdate`). */
export type ReplaceRolesPayload = { role_ids: number[] }

/** Body of `PUT /admin/users/{id}/permissions` (`AdminUserPermissionUpdate`). */
export type ReplacePermissionsPayload = { permission_ids: number[] }
