import { apiRequest } from './client'
import { ApiError } from './errors'
import type {
  StoreBannerCreatePayload,
  StoreBannerRead,
  StoreBannerUpdatePayload,
  StoreCategoryCreatePayload,
  StoreCategoryRead,
  StoreCategoryUpdatePayload,
  StoreItemCreatePayload,
  StoreItemRead,
  StoreItemUpdatePayload,
} from '../types/store'

const apiUrl = (import.meta.env.VITE_API_URL || 'http://localhost:8000').replace(/\/$/, '')

// ============================================================
// Lists (public endpoints — include inactive rows by default)
// ============================================================

export function listStoreCategories(): Promise<StoreCategoryRead[]> {
  return apiRequest<StoreCategoryRead[]>('/api/v1/store/categories?active_only=false')
}

export function listStoreItems(): Promise<StoreItemRead[]> {
  return apiRequest<StoreItemRead[]>('/api/v1/store/items')
}

export function listStoreBanners(): Promise<StoreBannerRead[]> {
  return apiRequest<StoreBannerRead[]>('/api/v1/store/banners?active_only=false')
}

// ============================================================
// Store Categories (admin)
// ============================================================

export function createStoreCategory(payload: StoreCategoryCreatePayload): Promise<StoreCategoryRead> {
  return apiRequest<StoreCategoryRead>('/api/v1/admin/store/categories', {
    method: 'POST',
    body: payload,
  })
}

export function updateStoreCategory(id: string, payload: StoreCategoryUpdatePayload): Promise<StoreCategoryRead> {
  return apiRequest<StoreCategoryRead>(`/api/v1/admin/store/categories/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: payload,
  })
}

export function deleteStoreCategory(id: string): Promise<void> {
  return apiRequest<void>(`/api/v1/admin/store/categories/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
}

// ============================================================
// Store Items (admin)
// ============================================================

export function createStoreItem(payload: StoreItemCreatePayload): Promise<StoreItemRead> {
  return apiRequest<StoreItemRead>('/api/v1/admin/store/items', {
    method: 'POST',
    body: payload,
  })
}

export function updateStoreItem(id: string, payload: StoreItemUpdatePayload): Promise<StoreItemRead> {
  return apiRequest<StoreItemRead>(`/api/v1/admin/store/items/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: payload,
  })
}

export function deleteStoreItem(id: string): Promise<void> {
  return apiRequest<void>(`/api/v1/admin/store/items/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
}

// ============================================================
// Store Banners (admin)
// ============================================================

export function createStoreBanner(payload: StoreBannerCreatePayload): Promise<StoreBannerRead> {
  return apiRequest<StoreBannerRead>('/api/v1/admin/store/banners', {
    method: 'POST',
    body: payload,
  })
}

export function updateStoreBanner(id: string, payload: StoreBannerUpdatePayload): Promise<StoreBannerRead> {
  return apiRequest<StoreBannerRead>(`/api/v1/admin/store/banners/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: payload,
  })
}

export function deleteStoreBanner(id: string): Promise<void> {
  return apiRequest<void>(`/api/v1/admin/store/banners/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
}

// ============================================================
// Media upload (`POST /api/v1/admin/store/media/image`) — multipart.
// Returns `{ image_url }`. Requires `store.write`.
// ============================================================

export async function uploadStoreImage(file: File): Promise<{ image_url: string }> {
  const form = new FormData()
  form.append('file', file)

  const response = await fetch(`${apiUrl}/api/v1/admin/store/media/image`, {
    method: 'POST',
    body: form,
    credentials: 'include',
  })

  if (!response.ok) {
    let message = 'تعذر رفع الصورة.'
    try {
      const payload = (await response.json()) as { detail?: string }
      if (payload.detail) message = payload.detail
    } catch {
      // keep default
    }
    throw new ApiError(response.status, message)
  }

  return (await response.json()) as { image_url: string }
}