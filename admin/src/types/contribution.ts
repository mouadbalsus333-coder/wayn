/**
 * Types for the Admin "Place Contributions" module.
 *
 * Mirrors the backend schemas in `backend/app/schemas/place_contribution.py`
 * and `backend/app/models/place_contribution.py`:
 * - PlaceContributionRead
 * - PlaceContributionListResponse
 * - PlaceContributionApproveRequest
 * - PlaceContributionRejectRequest
 */

export const CONTRIBUTION_TYPES = [
  'CREATE_PLACE',
  'UPDATE_PLACE',
  'ADD_IMAGE',
  'UPDATE_INFORMATION',
  'VERIFY_PLACE',
] as const
export type ContributionType = (typeof CONTRIBUTION_TYPES)[number]

export const CONTRIBUTION_STATUSES = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'CANCELLED',
] as const
export type ContributionStatus = (typeof CONTRIBUTION_STATUSES)[number]

export type ContributionRead = {
  id: string
  user_id: string
  place_id: string | null
  type: ContributionType
  status: ContributionStatus
  title: string
  description: string | null
  payload: Record<string, unknown>
  reviewed_by: number | null
  reviewed_at: string | null
  rejection_reason: string | null
  points_awarded: number
  created_at: string
  updated_at: string
}

/** Response of `GET /api/v1/admin/contributions` (offset/limit based). */
export interface ContributionListResponse {
  items: ContributionRead[]
  total: number
  offset: number
  limit: number
}

/** Query params of `GET /api/v1/admin/contributions`. */
export interface ContributionListParams {
  offset: number
  limit: number
  status?: ContributionStatus
  contribution_type?: ContributionType
}

/** Body of `POST /api/v1/admin/contributions/{id}/approve`. */
export interface ContributionApprovePayload {
  points?: number | null
}

/** Body of `POST /api/v1/admin/contributions/{id}/reject`. */
export interface ContributionRejectPayload {
  rejection_reason: string
}