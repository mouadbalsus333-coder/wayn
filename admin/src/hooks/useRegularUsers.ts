import { useQuery } from '@tanstack/react-query'
import { getRegularUser, listRegularUsers } from '../api/regularUsers'
import type { RegularUserListParams } from '../types/regularUser'

export function useRegularUsers(params: RegularUserListParams) {
  return useQuery({
    queryKey: ['admin', 'regular-users', 'list', params],
    queryFn: () => listRegularUsers(params),
    placeholderData: (previous) => previous,
  })
}

export function useRegularUser(id: string | undefined) {
  return useQuery({
    queryKey: ['admin', 'regular-users', 'detail', id],
    queryFn: () => getRegularUser(id as string),
    enabled: Boolean(id),
  })
}
