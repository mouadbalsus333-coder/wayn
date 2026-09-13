/**
 * Admin notifications API. Endpoints taken verbatim from
 * backend/app/api/routers/admin_notifications.py:
 * - POST /api/v1/admin/notifications/send   (notifications.send)
 * - GET  /api/v1/admin/notifications        (notifications.read)
 * There is no delete endpoint and none was invented here.
 */
import { apiRequest } from './client'
import type {
  AdminNotification,
  AdminNotificationListParams,
  AdminNotificationListResponse,
  AdminNotificationSendPayload,
} from '../types/adminNotification'

export async function sendAdminNotification(
  payload: AdminNotificationSendPayload,
): Promise<AdminNotification> {
  return apiRequest<AdminNotification>('/api/v1/admin/notifications/send', {
    method: 'POST',
    body: payload,
  })
}

export async function getAdminNotifications(
  params: AdminNotificationListParams,
): Promise<AdminNotificationListResponse> {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  return apiRequest<AdminNotificationListResponse>(
    `/api/v1/admin/notifications?${searchParams.toString()}`,
  )
}
