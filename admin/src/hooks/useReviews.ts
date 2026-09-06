import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { getReviews } from '../api/reviews'
import type { AdminReviewListParams } from '../types/review'

/**
 * Paginated admin reviews list. Mirrors the backend contract of
 * GET /api/v1/admin/reviews (search/filters are all server-side).
 */
export function useReviews(params: AdminReviewListParams) {
  return useQuery({
    queryKey: ['admin', 'reviews', params],
    queryFn: () => getReviews(params),
    placeholderData: keepPreviousData,
  })
}
