import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { getAdminUser, getAdminUsers } from '../api/adminUsers'
import type { AdminUserListParams } from '../types/adminUser'

export const ADMIN_USERS_QUERY_KEY = ['admin', 'admin-users'] as const

/** Paginated admin users list (`super_admin` only, enforced by the backend). */
export function useAdminUsers(params: AdminUserListParams) {
  return useQuery({
    queryKey: [...ADMIN_USERS_QUERY_KEY, params],
    queryFn: () => getAdminUsers(params),
    placeholderData: keepPreviousData,
  })
}

/** Single admin user details (`super_admin` only, enforced by the backend). */
export function useAdminUser(id: number | null) {
  return useQuery({
    queryKey: ['admin', 'admin-user', id],
    queryFn: () => getAdminUser(id as number),
    enabled: id !== null && Number.isFinite(id),
  })
}
