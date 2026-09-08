import { useMutation, useQueryClient } from '@tanstack/react-query'
import { approveContribution, rejectContribution } from '../api/contributions'
import type {
  ContributionApprovePayload,
  ContributionRead,
  ContributionRejectPayload,
} from '../types/contribution'

/**
 * Contributions moderation mutations. Backend enforces
 * `contributions.approve` / `contributions.reject` on the POST routes;
 * the UI conditionally shows actions only as a UX courtesy.
 * Success invalidates the list query so rows reflect the new status
 * without a full page reload.
 */
export function useApproveContributionMutation() {
  const queryClient = useQueryClient()
  return useMutation<ContributionRead, Error, { id: string; payload: ContributionApprovePayload }>({
    mutationFn: ({ id, payload }) => approveContribution(id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'contributions'] })
    },
  })
}

export function useRejectContributionMutation() {
  const queryClient = useQueryClient()
  return useMutation<ContributionRead, Error, { id: string; payload: ContributionRejectPayload }>({
    mutationFn: ({ id, payload }) => rejectContribution(id, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'contributions'] })
    },
  })
}