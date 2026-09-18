import type { PaginatedResponse } from './place'

/**
 * Types mirror backend/app/schemas/moderation.py exactly.
 * Keep both sides in sync when extending the moderation API.
 */

export type AppealStatus = 'PENDING' | 'UNDER_REVIEW' | 'RESOLVED' | 'REJECTED' | 'CANCELLED'
export type ReportStatus = AppealStatus

export type AppealType = 'INCORRECT_RATING' | 'MISLEADING_RATING' | 'OTHER'
export type ReportCategory = 'ABUSE' | 'INAPPROPRIATE_CONTENT' | 'SPAM' | 'FALSE_INFO' | 'OTHER'

/** What the admin decided to do with the post, if anything. */
export type PostAction = 'NONE' | 'DELETE_POST' | 'HIDE_POST' | 'LEAVE_AS_IS'

export type ModerationPostPreview = {
  id: string
  user_id: string
  place_id: string
  text: string | null
  image_url: string | null
  rating: number | null
  is_visible: boolean
  visibility_state: string | null
  deleted_at: string | null
  hidden_at: string | null
  created_at: string
  updated_at: string | null
  author_name: string | null
  author_username: string | null
  author_avatar: string | null
  place_name: string | null
  place_city: string | null
  likes_count: number
  saves_count: number
  comments_count: number
}

export type ModerationStats = {
  total: number
  pending: number
  under_review: number
  resolved: number
  rejected: number
  cancelled: number
}

/** Appeal as seen by the user who filed it. */
export type AppealRead = {
  id: string
  post_id: string
  user_id: string
  type: string
  reason: string
  status: string
  action_taken: string | null
  reviewed_at: string | null
  created_at: string
  updated_at: string
}

/** Report as seen by the user who filed it. */
export type ReportRead = {
  id: string
  post_id: string
  user_id: string
  category: string
  description: string
  status: string
  action_taken: string | null
  reviewed_at: string | null
  created_at: string
  updated_at: string
}

/** Compact appeal row for the admin list. */
export type AppealAdminListItem = {
  id: string
  post_id: string
  user_id: string
  type: string
  status: string
  reason: string
  action_taken: string | null
  created_at: string
  updated_at: string
  reviewed_at: string | null
  complainant_name: string | null
  complainant_username: string | null
  post_owner_name: string | null
  post_owner_username: string | null
}

/** Compact report row for the admin list. */
export type ReportAdminListItem = {
  id: string
  post_id: string
  user_id: string
  category: string
  status: string
  description: string
  action_taken: string | null
  created_at: string
  updated_at: string
  reviewed_at: string | null
  reporter_name: string | null
  reporter_username: string | null
  post_owner_name: string | null
  post_owner_username: string | null
}

/** Admin action trail entry (backend AdminActionLogRead). */
export type AdminActionLogRead = {
  id: string
  admin_user_id: string | null
  admin_email: string | null
  entity_type: string
  entity_id: string
  action: string
  notes: string | null
  created_at: string
}

/** Full appeal record for the admin detail page. */
export type AppealAdminRead = {
  id: string
  post_id: string
  user_id: string
  type: string
  reason: string
  status: string
  admin_notes: string | null
  action_taken: string | null
  reviewed_by: string | null
  reviewed_by_email: string | null
  reviewed_at: string | null
  created_at: string
  updated_at: string
  complainant_name: string | null
  complainant_username: string | null
  complainant_avatar: string | null
  complainant_email: string | null
  post_owner_id: string | null
  post_owner_name: string | null
  post_owner_username: string | null
  post_owner_avatar: string | null
  post: ModerationPostPreview | null
  actions: AdminActionLogRead[]
}

/** Full report record for the admin detail page. */
export type ReportAdminRead = {
  id: string
  post_id: string
  user_id: string
  category: string
  description: string
  status: string
  admin_notes: string | null
  action_taken: string | null
  reviewed_by: string | null
  reviewed_by_email: string | null
  reviewed_at: string | null
  created_at: string
  updated_at: string
  reporter_name: string | null
  reporter_username: string | null
  reporter_avatar: string | null
  reporter_email: string | null
  post_owner_id: string | null
  post_owner_name: string | null
  post_owner_username: string | null
  post_owner_avatar: string | null
  post: ModerationPostPreview | null
  actions: AdminActionLogRead[]
}

/** Backend AppealStatusUpdate: status change never touches the post. */
export type AppealStatusUpdate = {
  status: AppealStatus
  admin_notes?: string | null
}

export type ReportStatusUpdate = {
  status: ReportStatus
  admin_notes?: string | null
}

/** Backend PostActionUpdate: post decision, deliberately separate from status. */
export type PostActionUpdate = {
  action: 'DELETE_POST' | 'HIDE_POST' | 'LEAVE_AS_IS'
  notes?: string | null
}

export type AppealsListParams = {
  page: number
  limit: number
  search?: string
  status?: AppealStatus
  type?: string
  created_from?: string
  created_to?: string
}

export type ReportsListParams = {
  page: number
  limit: number
  search?: string
  status?: ReportStatus
  category?: string
  created_from?: string
  created_to?: string
}

export type AppealsResponse = PaginatedResponse<AppealAdminListItem>
export type ReportsResponse = PaginatedResponse<ReportAdminListItem>

/** Payload for the user filing an appeal. */
export type AppealCreate = {
  type: string
  reason: string
}

/** Payload for the user filing a report. */
export type ReportCreate = {
  category: string
  description: string
}