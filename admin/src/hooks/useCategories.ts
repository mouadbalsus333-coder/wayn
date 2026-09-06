import { useQuery } from '@tanstack/react-query'
import { getCategories } from '../api/places'

export function useCategories() {
  return useQuery({
    queryKey: ['admin', 'categories'],
    queryFn: getCategories,
  })
}