import type { PaginatedResponse } from './place'

/**
 * Mirrors `CommunityPostRead` (backend/app/schemas/community.py).
 * Viewer-specific fields (is_liked / is_saved / is_owner ...) are always
 * false in the admin context but kept to match the schema exactly.
 */
export type CommunityPostRead = {
  id: string
  user_id: string
  place_id: string
  text: string | null
  image_url: string | null
  rating: number | null
  is_visible: boolean
  created_at: string
  updated_at: string
  author_name: string | null
  author_username: string | null
  author_avatar: string | null
  place_name: string | null
  place_city: string | null
  author_points: number
  author_followers_count: number
  is_following_author: boolean
  is_owner: boolean
  likes_count: number
  saves_count: number
  comments_count: number
  is_liked: boolean
  is_saved: boolean
}

/** Mirrors `CommunityCommentRead`. */
export type CommunityCommentRead = {
  id: string
  post_id: string
  user_id: string
  text: string
  is_visible: boolean
  created_at: string
  updated_at: string
  author_name: string | null
  author_username: string | null
  author_avatar: string | null
}

export type CommunityPostsResponse = PaginatedResponse<CommunityPostRead>
export type CommunityCommentsResponse = PaginatedResponse<CommunityCommentRead>

export type CommunityPostsParams = {
  page: number
  limit: number
  search?: string
  is_visible?: boolean
}

/** Body of `PATCH /admin/community/posts/{id}/visibility` and comments equivalent. */
export type VisibilityUpdatePayload = {
  is_visible: boolean
}
