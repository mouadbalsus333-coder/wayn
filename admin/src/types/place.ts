/**
 * Types for the Admin Places module, mirroring the real backend schemas
 * (`backend/app/schemas/place.py` and `backend/app/schemas/pagination.py`).
 */

export const VERIFICATION_STATUSES = ['UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED'] as const
export type VerificationStatus = (typeof VERIFICATION_STATUSES)[number]

export const SORT_OPTIONS = [
  'created_at',
  'updated_at',
  'name',
  'rating',
  'reviews_count',
  'visits_count',
] as const
export type PlaceSortBy = (typeof SORT_OPTIONS)[number]
export type SortOrder = 'asc' | 'desc'

export type PlaceRead = {
  id: string
  category_id: string | null
  name: string
  city: string
  category_name: string
  image_url: string
  rating: number
  is_open: boolean
  is_active: boolean
  description: string | null
  address: string | null
  phone: string | null
  website: string | null
  latitude: number | null
  longitude: number | null
  images: string[]
  services: string[]
  opening_time: string | null
  closing_time: string | null
  reviews_count: number
  visits_count: number
  owner_user_id?: string | null
  verification_status?: VerificationStatus | null
  deleted_at?: string | null
}

export type PaginatedResponse<T> = {
  items: T[]
  total: number
  page: number
  limit: number
  pages: number
}

export type AdminPlaceListParams = {
  page: number
  limit: number
  search?: string | null
  category_id?: string | null
  verification_status?: VerificationStatus | null
  is_active?: boolean | null
  sort_by?: PlaceSortBy
  sort_order?: SortOrder
}

/** Response of `GET /api/v1/categories` (public). */
export type CategoryRead = {
  id: string
  name_ar: string
  name_en: string | null
  icon: string | null
  sort_order: number
  is_active: boolean
  parent_id?: string | null
}

/**
 * Payload for `PUT /api/v1/admin/places/{id}` (backend `PlaceUpdate`).
 * Every field is optional; the backend applies only the fields sent.
 */
export type PlaceUpdatePayload = {
  category_id?: string | null
  owner_user_id?: string | null
  verification_status?: VerificationStatus | null
  name?: string | null
  city?: string | null
  category_name?: string | null
  image_url?: string | null
  rating?: number | null
  is_open?: boolean | null
  is_active?: boolean | null
  description?: string | null
  address?: string | null
  phone?: string | null
  website?: string | null
  latitude?: number | null
  longitude?: number | null
  opening_time?: string | null
  closing_time?: string | null
}