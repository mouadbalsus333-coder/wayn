import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { listContributions } from '../api/contributions'
import type { ContributionListParams } from '../types/contribution'

export function useContributions(params: ContributionListParams) {
  return useQuery({
    queryKey: ['admin', 'contributions', params],
    queryFn: () => listContributions(params),
    placeholderData: keepPreviousData,
  })
}