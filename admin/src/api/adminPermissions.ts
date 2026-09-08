import { apiRequest } from './client'
import type { PermissionCatalogItem } from '../types/adminUser'
import type {
  PermissionCreatePayload,
  PermissionUpdatePayload,
} from '../types/permission'

/**
 * `GET /api/v1/admin/permissions` — the full permission catalog.
 * Protected by `require_role("super_admin")` in the backend.
 */
export function getPermissionCatalog(): Promise<PermissionCatalogItem[]> {
  return apiRequest<PermissionCatalogItem[]>('/api/v1/admin/permissions')
}

/** `POST /api/v1/admin/permissions` — requires `super_admin`. */
export function createPermission(payload: PermissionCreatePayload): Promise<PermissionCatalogItem> {
  return apiRequest<PermissionCatalogItem>('/api/v1/admin/permissions', {
    method: 'POST',
    body: payload,
  })
}

/** `PUT /api/v1/admin/permissions/{id}` — requires `super_admin`. */
export function updatePermission(id: number, payload: PermissionUpdatePayload): Promise<PermissionCatalogItem> {
  return apiRequest<PermissionCatalogItem>(`/api/v1/admin/permissions/${id}`, {
    method: 'PUT',
    body: payload,
  })
}

/** `DELETE /api/v1/admin/permissions/{id}` — requires `super_admin`. */
export function deletePermission(id: number): Promise<void> {
  return apiRequest<void>(`/api/v1/admin/permissions/${id}`, {
    method: 'DELETE',
  })
}