import { useMutation, useQueryClient } from '@tanstack/react-query'
import { createPointRule, updatePointRule } from '../api/pointRules'
import type { PointRuleCreatePayload, PointRuleUpdatePayload } from '../types/pointRule'

function invalidatePointRules(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: ['admin', 'point-rules'] })
}

export function useCreatePointRuleMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (payload: PointRuleCreatePayload) => createPointRule(payload),
    onSuccess: () => invalidatePointRules(queryClient),
  })
}

export function useUpdatePointRuleMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, payload }: { id: number; payload: PointRuleUpdatePayload }) =>
      updatePointRule(id, payload),
    onSuccess: () => invalidatePointRules(queryClient),
  })
}
