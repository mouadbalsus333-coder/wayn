import { apiRequest } from './client'
import type {
  AdminPlaceListParams,
  CategoryRead,
  PaginatedResponse,
  PlaceRead,
  PlaceUpdatePayload,
} from '../types/place'

export function getPlaces(params: AdminPlaceListParams) {
  const query = buildQuery(params)
  return apiRequest<PaginatedResponse<PlaceRead>>(`/api/v1/admin/places?${query}`)
}

export function getCategories() {
  return apiRequest<CategoryRead[]>('/api/v1/categories')
}

export function updatePlace(id: string, payload: PlaceUpdatePayload) {
  return apiRequest<PlaceRead>(`/api/v1/admin/places/${encodeURIComponent(id)}`, {
    method: 'PUT',
    body: payload,
  })
}

export function deletePlace(id: string) {
  return apiRequest<void>(`/api/v1/admin/places/${encodeURIComponent(id)}`, {
    method: 'DELETE',
  })
}

function buildQuery(params: AdminPlaceListParams) {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  if (params.search !== undefined && params.search !== null && params.search.trim() !== '') {
    searchParams.set('search', params.search.trim())
  }
  if (params.category_id) searchParams.set('category_id', params.category_id)
  if (params.verification_status) searchParams.set('verification_status', params.verification_status)
  if (params.is_active !== null && params.is_active !== undefined) {
    searchParams.set('is_active', String(params.is_active))
  }
  if (params.sort_by) searchParams.set('sort_by', params.sort_by)
  if (params.sort_order) searchParams.set('sort_order', params.sort_order)
  return searchParams.toString()
}