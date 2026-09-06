/**
 * Types for admin reviews moderation. Mirrors backend `ReviewRead`
 * (backend/app/schemas/review.py) and the query params of
 * `GET /api/v1/admin/reviews` (backend/app/api/routers/admin_reviews.py).
 */
import type { PaginatedResponse } from './place'

export interface AdminReview {
  id: string
  place_id: string
  user_id: string
  rating: number
  comment: string | null
  images: string[]
  is_visible: boolean
  created_at: string
  updated_at: string
}

export type ReviewListResponse = PaginatedResponse<AdminReview>

export interface AdminReviewListParams {
  page: number
  limit: number
  place_id?: string
  rating?: number
  is_visible?: boolean
  search?: string
  created_from?: string
  created_to?: string
}

export interface ReviewVisibilityPayload {
  is_visible: boolean
}
