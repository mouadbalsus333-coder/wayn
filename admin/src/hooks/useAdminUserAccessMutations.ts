import { useMutation, useQueryClient } from '@tanstack/react-query'
import { userFacingError } from '../api/errors'
import {
  addPermissionToAdminUser,
  addRoleToAdminUser,
  removePermissionFromAdminUser,
  removeRoleFromAdminUser,
} from '../api/adminUsers'
import type { AdminUserPermissionRead, RoleRead } from '../types/adminUser'

/**
 * Mutations over an admin user's roles and direct permissions.
 *
 * Backend behaviour discovered from the code:
 * - All endpoints are protected by `require_role("super_admin")`.
 * - Unknown role/permission ids → 400 (roles) / 404 (permissions).
 * - Removing a non-assigned role is idempotent on the backend.
 * - The repositories bump the target's `token_version` on role and
 *   permission mutations, which ends the target's current session.
 * - The backend does NOT protect the `super_admin` role from removal —
 *   the UI shows a confirmation warning but cannot block it.
 */

function useInvalidateUserAccess() {
  const queryClient = useQueryClient()
  return (userId: number) => {
    void queryClient.invalidateQueries({ queryKey: ['admin', 'admin-user', userId] })
    void queryClient.invalidateQueries({ queryKey: ['admin', 'admin-user-roles', userId] })
    void queryClient.invalidateQueries({ queryKey: ['admin', 'admin-user-permissions', userId] })
    void queryClient.invalidateQueries({ queryKey: ['admin', 'admin-user-resolved', userId] })
    void queryClient.invalidateQueries({ queryKey: ['admin', 'admin-users'] })
  }
}

export function useAddRoleMutation() {
  const queryClient = useQueryClient()
  const invalidate = useInvalidateUserAccess()
  return useMutation({
    mutationFn: ({ userId, roleId }: { userId: number; roleId: number }) =>
      addRoleToAdminUser(userId, roleId),
    onSuccess: (roles, { userId }) => {
      queryClient.setQueryData(['admin', 'admin-user-roles', userId], roles)
      invalidate(userId)
    },
  })
}

export function useRemoveRoleMutation() {
  const queryClient = useQueryClient()
  const invalidate = useInvalidateUserAccess()
  return useMutation({
    mutationFn: ({ userId, roleId }: { userId: number; roleId: number }) =>
      removeRoleFromAdminUser(userId, roleId),
    onSuccess: (roles, { userId }) => {
      queryClient.setQueryData(['admin', 'admin-user-roles', userId], roles)
      invalidate(userId)
    },
  })
}

export function useAddPermissionMutation() {
  const queryClient = useQueryClient()
  const invalidate = useInvalidateUserAccess()
  return useMutation({
    mutationFn: ({ userId, permissionId }: { userId: number; permissionId: number }) =>
      addPermissionToAdminUser(userId, permissionId),
    onSuccess: (permissions, { userId }) => {
      queryClient.setQueryData(['admin', 'admin-user-permissions', userId], permissions)
      invalidate(userId)
    },
  })
}

export function useRemovePermissionMutation() {
  const queryClient = useQueryClient()
  const invalidate = useInvalidateUserAccess()
  return useMutation({
    mutationFn: ({ userId, permissionId }: { userId: number; permissionId: number }) =>
      removePermissionFromAdminUser(userId, permissionId),
    onSuccess: (permissions, { userId }) => {
      queryClient.setQueryData(['admin', 'admin-user-permissions', userId], permissions)
      invalidate(userId)
    },
  })
}

/** Human-readable mutation failure message (403 stays a permission error, never a logout). */
export function accessMutationError(error: unknown): string | null {
  return error ? userFacingError(error) : null
}

export type { AdminUserPermissionRead, RoleRead }