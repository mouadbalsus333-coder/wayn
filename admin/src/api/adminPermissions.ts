import { apiRequest } from './client'
import type { PermissionCatalogItem } from '../types/adminUser'

/**
 * `GET /api/v1/admin/permissions` — the full permission catalog.
 * Protected by `require_role("super_admin")` in the backend.
 */
export function getPermissionCatalog(): Promise<PermissionCatalogItem[]> {
  return apiRequest<PermissionCatalogItem[]>('/api/v1/admin/permissions')
}