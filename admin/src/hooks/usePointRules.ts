import { useQuery } from '@tanstack/react-query'
import { listPointRules } from '../api/pointRules'

export function usePointRules() {
  return useQuery({
    queryKey: ['admin', 'point-rules'],
    queryFn: listPointRules,
  })
}
