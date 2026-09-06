import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { listPostComments, listCommunityPosts } from '../api/community'
import type { CommunityPostsParams } from '../types/community'

export function useCommunityPosts(params: CommunityPostsParams) {
  return useQuery({
    queryKey: ['admin', 'community', 'posts', params],
    queryFn: () => listCommunityPosts(params),
    placeholderData: keepPreviousData,
  })
}

export function usePostComments(
  postId: string,
  options: { page: number; limit: number; is_visible?: boolean },
) {
  return useQuery({
    queryKey: ['admin', 'community', 'posts', postId, 'comments', options],
    queryFn: () => listPostComments(postId, options),
    placeholderData: keepPreviousData,
  })
}
