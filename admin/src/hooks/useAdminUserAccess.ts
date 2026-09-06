import { useQuery } from '@tanstack/react-query'
import {
  getAdminUserDirectPermissions,
  getAdminUserResolvedPermissions,
  getAdminUserRoles,
} from '../api/adminUsers'
import { getPermissionCatalog } from '../api/adminPermissions'

/** Roles currently assigned to an admin user (`GET /admin/users/{id}/roles`). */
export function useAdminUserRoles(id: number | null) {
  return useQuery({
    queryKey: ['admin', 'admin-user-roles', id],
    queryFn: () => getAdminUserRoles(id as number),
    enabled: id !== null && Number.isFinite(id),
  })
}

/** Direct permissions of an admin user (`GET /admin/users/{id}/permissions`). */
export function useAdminUserDirectPermissions(id: number | null) {
  return useQuery({
    queryKey: ['admin', 'admin-user-permissions', id],
    queryFn: () => getAdminUserDirectPermissions(id as number),
    enabled: id !== null && Number.isFinite(id),
  })
}

/** Resolved permissions (active roles + direct) (`GET /admin/users/{id}/resolved-permissions`). */
export function useAdminUserResolvedPermissions(id: number | null) {
  return useQuery({
    queryKey: ['admin', 'admin-user-resolved', id],
    queryFn: () => getAdminUserResolvedPermissions(id as number),
    enabled: id !== null && Number.isFinite(id),
  })
}

/** Full permission catalog (`GET /admin/permissions`, `super_admin` only). */
export function usePermissionCatalog() {
  return useQuery({
    queryKey: ['admin', 'permission-catalog'],
    queryFn: getPermissionCatalog,
    staleTime: 5 * 60 * 1000,
  })
}