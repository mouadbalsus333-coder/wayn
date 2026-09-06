import { useMutation, useQueryClient } from '@tanstack/react-query'
import { updateRegularUserStatus } from '../api/regularUsers'
import type {
  RegularUserRead,
  RegularUserStatusUpdatePayload,
} from '../types/regularUser'

/**
 * Updates a regular user's account status via
 * `PATCH /api/v1/admin/regular-users/{id}/status`.
 *
 * The backend requires `users.update` for permissive changes and
 * `users.disable` for restricted ones (deactivation / HIDDEN / SUSPENDED /
 * BANNED) and answers 403 otherwise. Changing the status bumps the user's
 * `token_version`, ending their mobile session.
 */
export function useRegularUserStatusMutation(userId: string) {
  const queryClient = useQueryClient()

  return useMutation<RegularUserRead, Error, RegularUserStatusUpdatePayload>({
    mutationFn: (payload) => updateRegularUserStatus(userId, payload),
    onSuccess: (updated) => {
      queryClient.setQueryData<RegularUserRead>(
        ['admin', 'regular-users', 'detail', userId],
        updated,
      )
      void queryClient.invalidateQueries({
        queryKey: ['admin', 'regular-users', 'list'],
      })
    },
  })
}
