import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getAdminNotifications, sendAdminNotification } from '../api/adminNotifications'
import type { AdminNotificationListParams, AdminNotificationSendPayload } from '../types/adminNotification'

export function useAdminNotifications(params: AdminNotificationListParams) {
  return useQuery({
    queryKey: ['admin', 'notifications', params],
    queryFn: () => getAdminNotifications(params),
    placeholderData: keepPreviousData,
  })
}

export function useSendAdminNotification() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (payload: AdminNotificationSendPayload) => sendAdminNotification(payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'notifications'] })
    },
  })
}
