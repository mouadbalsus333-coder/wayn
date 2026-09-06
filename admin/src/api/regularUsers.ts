import { apiRequest } from './client'
import type {
  RegularUserListParams,
  RegularUserRead,
  RegularUserStatusUpdatePayload,
  RegularUsersResponse,
} from '../types/regularUser'

const base = '/api/v1/admin/regular-users'

export function listRegularUsers(params: RegularUserListParams) {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  if (params.search && params.search.trim() !== '') {
    searchParams.set('search', params.search.trim())
  }
  if (params.account_status) searchParams.set('account_status', params.account_status)
  if (params.is_active !== undefined) searchParams.set('is_active', String(params.is_active))
  if (params.is_verified !== undefined) {
    searchParams.set('is_verified', String(params.is_verified))
  }
  if (params.sort_by) searchParams.set('sort_by', params.sort_by)
  if (params.sort_order) searchParams.set('sort_order', params.sort_order)
  return apiRequest<RegularUsersResponse>(`${base}?${searchParams.toString()}`)
}

export function getRegularUser(id: string) {
  return apiRequest<RegularUserRead>(
    `${base}/${encodeURIComponent(id)}`,
  )
}

export function updateRegularUserStatus(
  id: string,
  payload: RegularUserStatusUpdatePayload,
) {
  return apiRequest<RegularUserRead>(
    `${base}/${encodeURIComponent(id)}/status`,
    { method: 'PATCH', body: payload },
  )
}
