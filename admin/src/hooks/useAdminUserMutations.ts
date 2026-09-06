import { useMutation, useQueryClient } from '@tanstack/react-query'
import { activateAdminUser, deactivateAdminUser } from '../api/adminUsers'
import { ADMIN_USERS_QUERY_KEY } from './useAdminUsers'

/**
 * Activate/deactivate an admin account using the real endpoints
 * `PATCH /admin/users/{id}/activate|deactivate`. The backend enforces
 * the `super_admin` role and refuses to deactivate a Super Admin (403).
 * Changing status bumps `token_version`, which ends the target's session.
 */
export function useAdminUserStatusMutation() {
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: ({ id, active }: { id: number; active: boolean }) =>
      active ? activateAdminUser(id) : deactivateAdminUser(id),
    onSuccess: (updated) => {
      queryClient.setQueryData(['admin', 'admin-user', updated.id], updated)
      void queryClient.invalidateQueries({ queryKey: [...ADMIN_USERS_QUERY_KEY] })
    },
  })

  return mutation
}
