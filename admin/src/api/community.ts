import { apiRequest } from './client'
import type {
  CommunityCommentsResponse,
  CommunityPostsResponse,
  CommunityPostsParams,
  CommunityPostRead,
  CommunityCommentRead,
  VisibilityUpdatePayload,
} from '../types/community'

const base = '/api/v1/admin/community'

export function listCommunityPosts(params: CommunityPostsParams) {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  if (params.search && params.search.trim() !== '') {
    searchParams.set('search', params.search.trim())
  }
  if (params.is_visible !== undefined) {
    searchParams.set('is_visible', String(params.is_visible))
  }
  return apiRequest<CommunityPostsResponse>(`${base}/posts?${searchParams.toString()}`)
}

export function setPostVisibility(postId: string, payload: VisibilityUpdatePayload) {
  return apiRequest<CommunityPostRead>(
    `${base}/posts/${encodeURIComponent(postId)}/visibility`,
    { method: 'PATCH', body: payload },
  )
}

export function listPostComments(
  postId: string,
  options: { page: number; limit: number; is_visible?: boolean },
) {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(options.page))
  searchParams.set('limit', String(options.limit))
  if (options.is_visible !== undefined) {
    searchParams.set('is_visible', String(options.is_visible))
  }
  return apiRequest<CommunityCommentsResponse>(
    `${base}/posts/${encodeURIComponent(postId)}/comments?${searchParams.toString()}`,
  )
}

export function setCommentVisibility(commentId: string, payload: VisibilityUpdatePayload) {
  return apiRequest<CommunityCommentRead>(
    `${base}/comments/${encodeURIComponent(commentId)}/visibility`,
    { method: 'PATCH', body: payload },
  )
}
