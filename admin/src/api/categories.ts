import { apiRequest } from './client'
import type { CategoryCreatePayload, CategoryRead, CategoryUpdatePayload } from '../types/category'

/** `GET /api/v1/categories` — public list (also used by the Places module). */
export function listCategories(): Promise<CategoryRead[]> {
  return apiRequest<CategoryRead[]>('/api/v1/categories')
}

/** `POST /api/v1/admin/categories` — requires `categories.write`. */
export function createCategory(payload: CategoryCreatePayload): Promise<CategoryRead> {
  return apiRequest<CategoryRead>('/api/v1/admin/categories', {
    method: 'POST',
    body: payload,
  })
}

/** `PUT /api/v1/admin/categories/{id}` — requires `categories.write`. */
export function updateCategory(id: string, payload: CategoryUpdatePayload): Promise<CategoryRead> {
  return apiRequest<CategoryRead>(`/api/v1/admin/categories/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: payload,
  })
}

/** `DELETE /api/v1/admin/categories/{id}` — requires `categories.delete`. */
export function deleteCategory(id: string): Promise<void> {
  return apiRequest<void>(`/api/v1/admin/categories/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
}