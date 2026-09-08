/**
 * Admin Permission Catalog CRUD.
 * Mirrors `backend/app/schemas/permission.py`. The read shape (PermissionRead)
 * lives in `types/adminUser.ts` as PermissionCatalogItem.
 */
import type { PermissionCatalogItem } from './adminUser'

export type { PermissionCatalogItem }

/** Body of `POST /api/v1/admin/permissions` (`PermissionCreate`). */
export type PermissionCreatePayload = {
  name: string
  description?: string | null
}

/** Body of `PUT /api/v1/admin/permissions/{id}` (`PermissionUpdate`). */
export type PermissionUpdatePayload = {
  name?: string | null
  description?: string | null
}