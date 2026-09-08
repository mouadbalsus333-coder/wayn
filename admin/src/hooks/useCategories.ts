import { useQuery } from '@tanstack/react-query'
import { listCategories } from '../api/categories'

export function useCategories() {
  return useQuery({
    queryKey: ['admin', 'categories'],
    queryFn: listCategories,
  })
}