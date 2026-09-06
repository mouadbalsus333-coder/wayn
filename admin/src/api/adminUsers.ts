import { apiRequest } from './client'
import type { PaginatedResponse } from '../types/place'
import type { AdminUserListParams, AdminUserPermissionRead, AdminUserRead, ReplacePermissionsPayload, ReplaceRolesPayload, RoleRead } from '../types/adminUser'

function buildQuery(params: AdminUserListParams): string {
  const query = new URLSearchParams()
  query.set('page', String(params.page))
  query.set('limit', String(params.limit))
  if (params.search) query.set('search', params.search)
  if (params.is_active !== null && params.is_active !== undefined) {
    query.set('is_active', String(params.is_active))
  }
  if (params.role) query.set('role', params.role)
  return query.toString()
}

/** `GET /api/v1/admin/users` — requires the `super_admin` role (backend `require_role`). */
export function getAdminUsers(params: AdminUserListParams): Promise<PaginatedResponse<AdminUserRead>> {
  return apiRequest<PaginatedResponse<AdminUserRead>>(`/api/v1/admin/users?${buildQuery(params)}`)
}

/** `GET /api/v1/admin/users/{id}` — requires the `super_admin` role. */
export function getAdminUser(id: number): Promise<AdminUserRead> {
  return apiRequest<AdminUserRead>(`/api/v1/admin/users/${id}`)
}

/** `PATCH /api/v1/admin/users/{id}/activate` — requires the `super_admin` role. */
export function activateAdminUser(id: number): Promise<AdminUserRead> {
  return apiRequest<AdminUserRead>(`/api/v1/admin/users/${id}/activate`, { method: 'PATCH' })
}

/**
 * `PATCH /api/v1/admin/users/{id}/deactivate` — requires the `super_admin` role.
 * The backend returns 403 when the target is a Super Admin.
 */
export function deactivateAdminUser(id: number): Promise<AdminUserRead> {
  return apiRequest<AdminUserRead>(`/api/v1/admin/users/${id}/deactivate`, { method: 'PATCH' })
}

// ============================================================
// Roles of an admin user (`super_admin` role, backend-enforced).
// ============================================================

/** `GET /api/v1/admin/users/{id}/roles`. */
export function getAdminUserRoles(id: number): Promise<RoleRead[]> {
  return apiRequest<RoleRead[]>(`/api/v1/admin/users/${id}/roles`)
}

/** `PUT /api/v1/admin/users/{id}/roles` — bulk replacement (`{ role_ids }`). */
export function replaceAdminUserRoles(id: number, body: ReplaceRolesPayload): Promise<RoleRead[]> {
  return apiRequest<RoleRead[]>(`/api/v1/admin/users/${id}/roles`, { method: 'PUT', body: JSON.stringify(body) })
}

/**
 * `POST /api/v1/admin/users/{id}/roles/{roleId}` — 400 when the role id is unknown.
 * NOTE: there is no backend endpoint that lists all available roles
 * (`GET /admin/roles` does not exist), so the UI cannot offer a role picker.
 */
export function addRoleToAdminUser(id: number, roleId: number): Promise<RoleRead[]> {
  return apiRequest<RoleRead[]>(`/api/v1/admin/users/${id}/roles/${roleId}`, { method: 'POST' })
}

/** `DELETE /api/v1/admin/users/{id}/roles/{roleId}` — idempotent on unknown role ids. */
export function removeRoleFromAdminUser(id: number, roleId: number): Promise<RoleRead[]> {
  return apiRequest<RoleRead[]>(`/api/v1/admin/users/${id}/roles/${roleId}`, { method: 'DELETE' })
}

// ============================================================
// Direct permissions of an admin user (`super_admin` role).
// ============================================================

/** `GET /api/v1/admin/users/{id}/permissions`. */
export function getAdminUserDirectPermissions(id: number): Promise<AdminUserPermissionRead[]> {
  return apiRequest<AdminUserPermissionRead[]>(`/api/v1/admin/users/${id}/permissions`)
}

/** `PUT /api/v1/admin/users/{id}/permissions` — bulk replacement (`{ permission_ids }`). */
export function replaceAdminUserPermissions(id: number, body: ReplacePermissionsPayload): Promise<AdminUserPermissionRead[]> {
  return apiRequest<AdminUserPermissionRead[]>(`/api/v1/admin/users/${id}/permissions`, { method: 'PUT', body: JSON.stringify(body) })
}

/** `POST /api/v1/admin/users/{id}/permissions/{permissionId}` — 404 when unknown. */
export function addPermissionToAdminUser(id: number, permissionId: number): Promise<AdminUserPermissionRead[]> {
  return apiRequest<AdminUserPermissionRead[]>(`/api/v1/admin/users/${id}/permissions/${permissionId}`, { method: 'POST' })
}

/** `DELETE /api/v1/admin/users/{id}/permissions/{permissionId}` — 404 when unknown. */
export function removePermissionFromAdminUser(id: number, permissionId: number): Promise<AdminUserPermissionRead[]> {
  return apiRequest<AdminUserPermissionRead[]>(`/api/v1/admin/users/${id}/permissions/${permissionId}`, { method: 'DELETE' })
}

/**
 * `GET /api/v1/admin/users/{id}/resolved-permissions` — merged permissions from
 * active roles + direct permissions, sorted by name. The response does NOT
 * distinguish the source of each permission.
 */
export function getAdminUserResolvedPermissions(id: number): Promise<AdminUserPermissionRead[]> {
  return apiRequest<AdminUserPermissionRead[]>(`/api/v1/admin/users/${id}/resolved-permissions`)
}
