import { useMutation, useQueryClient } from '@tanstack/react-query'
import { setReviewVisibility } from '../api/reviews'
import type { AdminReview } from '../types/review'

/**
 * Visibility moderation for a single review.
 * PATCH /api/v1/admin/reviews/{id}/visibility — protected by
 * `reviews.moderate` in the backend. Changing visibility updates the
 * cached list rows without a full reload.
 */
export function useReviewVisibilityMutation() {
  const queryClient = useQueryClient()

  return useMutation<AdminReview, Error, { reviewId: string; isVisible: boolean }>({
    mutationFn: ({ reviewId, isVisible }) => setReviewVisibility(reviewId, { is_visible: isVisible }),
    onSuccess: (updated) => {
      queryClient.setQueriesData<{ items: AdminReview[] }>(
        { queryKey: ['admin', 'reviews'] },
        (existing) =>
          existing
            ? {
                ...existing,
                items: existing.items.map((review) =>
                  review.id === updated.id ? updated : review,
                ),
              }
            : existing,
      )
    },
  })
}
