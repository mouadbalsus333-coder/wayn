import { useMutation, useQueryClient } from '@tanstack/react-query'
import { createAdminUser, deleteAdminUser, updateAdminUser } from '../api/adminUsers'
import { ADMIN_USERS_QUERY_KEY } from './useAdminUsers'
import type { AdminUserCreatePayload, AdminUserUpdatePayload } from '../types/adminUser'

function invalidateAdminUsers(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: [...ADMIN_USERS_QUERY_KEY] })
}

/** `POST /api/v1/admin/users` — `super_admin` only (backend-enforced). */
export function useCreateAdminUserMutation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (payload: AdminUserCreatePayload) => createAdminUser(payload),
    onSuccess: (created) => {
      // Seed the single-user cache so a fresh detail page has data.
      qc.setQueryData(['admin', 'admin-user', created.id], created)
      invalidateAdminUsers(qc)
    },
  })
}

/** `PUT /api/v1/admin/users/{id}` — `super_admin` only (backend-enforced). */
export function useUpdateAdminUserMutation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, payload }: { id: number; payload: AdminUserUpdatePayload }) =>
      updateAdminUser(id, payload),
    onSuccess: (updated) => {
      qc.setQueryData(['admin', 'admin-user', updated.id], updated)
      invalidateAdminUsers(qc)
    },
  })
}

/** `DELETE /api/v1/admin/users/{id}` — `super_admin` only (backend-enforced). */
export function useDeleteAdminUserMutation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: number) => deleteAdminUser(id),
    onSuccess: (_data, variables) => {
      qc.removeQueries({ queryKey: ['admin', 'admin-user', variables] })
      invalidateAdminUsers(qc)
    },
  })
}