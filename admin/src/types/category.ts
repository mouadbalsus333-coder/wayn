/**
 * Admin Categories module.
 * Mirrors `backend/app/schemas/category.py`. CategoryRead is shared with the
 * public list used by the Places module (`types/place.ts`).
 */
import type { CategoryRead } from './place'

export type { CategoryRead }

/** Body of `POST /api/v1/admin/categories` (`CategoryCreate`). */
export type CategoryCreatePayload = {
  name_ar: string
  name_en?: string | null
  icon?: string | null
  sort_order?: number
  is_active?: boolean
  parent_id?: string | null
}

/** Body of `PUT /api/v1/admin/categories/{id}` (`CategoryUpdate`). */
export type CategoryUpdatePayload = {
  name_ar?: string | null
  name_en?: string | null
  icon?: string | null
  sort_order?: number | null
  is_active?: boolean | null
  parent_id?: string | null
}