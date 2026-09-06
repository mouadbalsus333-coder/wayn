import { useMutation, useQueryClient } from '@tanstack/react-query'
import { setCommentVisibility, setPostVisibility } from '../api/community'
import type { VisibilityUpdatePayload } from '../types/community'

/**
 * Community moderation mutations. The backend enforces
 * `community.moderate` on visibility PATCHes; the UI hides actions only
 * as a UX courtesy (see RequirePermission for the routes).
 */
export function usePostVisibilityMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ postId, payload }: { postId: string; payload: VisibilityUpdatePayload }) =>
      setPostVisibility(postId, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'community'] })
    },
  })
}

export function useCommentVisibilityMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({
      commentId,
      payload,
    }: {
      commentId: string
      payload: VisibilityUpdatePayload
    }) => setCommentVisibility(commentId, payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'community'] })
    },
  })
}
