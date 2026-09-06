import type { PaginatedResponse } from './place'

/**
 * Regular (mobile app) users as exposed by the admin API.
 * Mirrors `AdminRegularUserRead` in
 * `backend/app/schemas/admin_regular_user.py`.
 */
export type AccountStatus = 'ACTIVE' | 'HIDDEN' | 'SUSPENDED' | 'BANNED'

export type RegularUserRead = {
  id: string
  email: string
  full_name: string
  username: string
  phone: string | null
  account_status: AccountStatus
  is_active: boolean
  is_verified: boolean
  points: number
  created_at: string
  last_login_at: string | null
}

export type RegularUsersResponse = PaginatedResponse<RegularUserRead>

export type RegularUserSortBy =
  | 'created_at'
  | 'updated_at'
  | 'full_name'
  | 'username'
  | 'last_login_at'
  | 'points'

export type RegularUserListParams = {
  page: number
  limit: number
  search?: string
  account_status?: AccountStatus
  is_active?: boolean
  is_verified?: boolean
  sort_by?: RegularUserSortBy
  sort_order?: 'asc' | 'desc'
}

/**
 * Body of `PATCH /api/v1/admin/regular-users/{id}/status`.
 * Mirrors `AdminRegularUserStatusUpdate`; at least one of
 * `account_status` / `is_active` is required by the backend (400 otherwise).
 */
export type RegularUserStatusUpdatePayload = {
  account_status?: AccountStatus
  is_active?: boolean
  status_reason?: string
  suspended_until?: string
}

export const ACCOUNT_STATUS_LABELS: Record<AccountStatus, string> = {
  ACTIVE: 'نشط',
  HIDDEN: 'مخفي',
  SUSPENDED: 'موقوف',
  BANNED: 'محظور',
}

/** Statuses the backend treats as "restricted" (require `users.disable`). */
export const RESTRICTED_STATUSES: ReadonlySet<AccountStatus> = new Set([
  'HIDDEN',
  'SUSPENDED',
  'BANNED',
])
