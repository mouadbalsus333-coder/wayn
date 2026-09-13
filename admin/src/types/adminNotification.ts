/**
 * Types for admin notifications. Mirrors backend
 * backend/app/schemas/admin_notification.py:
 * - AdminNotificationSendRequest (POST /api/v1/admin/notifications/send)
 * - AdminNotificationListResponse (GET /api/v1/admin/notifications)
 * Note: only `in_app` channel is functional today; push/both require FCM
 * which is not implemented yet.
 */

export type NotificationChannel = 'in_app' | 'push' | 'both'
export type NotificationType = 'broadcast'

export interface AdminNotificationSendPayload {
  title: string
  body: string
  channel: NotificationChannel
  notification_type: NotificationType
}

export interface AdminNotification {
  id: string
  title: string
  body: string
  channel: string
  notification_type: string
  sent_by_admin_id: number
  total_recipients: number | null
  delivered_count: number
  failed_count: number
  status: string
  scheduled_at: string | null
  sent_at: string | null
  created_at: string
  updated_at: string | null
}

export interface AdminNotificationListResponse {
  items: AdminNotification[]
  total: number
  page: number
  limit: number
  pages: number
}

export interface AdminNotificationListParams {
  page: number
  limit: number
}
