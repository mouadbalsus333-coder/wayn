/**
 * Admin reviews API. Endpoints and shapes are taken verbatim from
 * backend/app/api/routers/admin_reviews.py:
 * - GET  /api/v1/admin/reviews                 (reviews.read)
 * - PATCH /api/v1/admin/reviews/{id}/visibility (reviews.moderate)
 * There is no detail endpoint and no delete endpoint in the backend;
 * none were invented here.
 */
import { apiRequest } from './client'
import type {
  AdminReview,
  AdminReviewListParams,
  ReviewListResponse,
  ReviewVisibilityPayload,
} from '../types/review'

export async function getReviews(
  params: AdminReviewListParams,
): Promise<ReviewListResponse> {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  if (params.place_id) searchParams.set('place_id', params.place_id)
  if (params.rating !== undefined) searchParams.set('rating', String(params.rating))
  if (params.is_visible !== undefined) searchParams.set('is_visible', String(params.is_visible))
  if (params.search) searchParams.set('search', params.search)
  if (params.created_from) searchParams.set('created_from', params.created_from)
  if (params.created_to) searchParams.set('created_to', params.created_to)

  return apiRequest<ReviewListResponse>(`/api/v1/admin/reviews?${searchParams.toString()}`)
}

export async function setReviewVisibility(
  reviewId: string,
  payload: ReviewVisibilityPayload,
): Promise<AdminReview> {
  return apiRequest<AdminReview>(`/api/v1/admin/reviews/${reviewId}/visibility`, {
    method: 'PATCH',
    body: payload,
  })
}
