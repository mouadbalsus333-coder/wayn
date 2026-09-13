import { useCallback, useMemo, useState, type FormEvent } from 'react'
import {
  Bell,
  CheckCircle2,
  Clock3,
  FileText,
  LayoutGrid,
  Radio,
  Send,
  Smartphone,
  Users,
  XCircle,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import {
  useAdminNotifications,
  useSendAdminNotification,
} from '../../hooks/useAdminNotifications'
import { useAuth } from '../../auth/useAuth'
import { permissions } from '../../permissions/permissionNames'
import type { NotificationChannel } from '../../types/adminNotification'

function formatDate(value: string | null): string {
  if (!value) return '—'

  const date = new Date(value)

  if (Number.isNaN(date.getTime())) return value

  return date.toLocaleString('ar', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

const CHANNEL_LABELS: Record<string, string> = {
  in_app: 'داخل التطبيق',
  push: 'Push',
  both: 'التطبيق + Push',
}

const STATUS_LABELS: Record<string, string> = {
  in_progress: 'قيد التنفيذ',
  completed: 'مكتمل',
  partial: 'جزئي',
  failed: 'فاشل',
  pending: 'معلّق',
  scheduled: 'مجدول',
}

const CHANNEL_OPTIONS: Array<{
  value: NotificationChannel
  label: string
  description: string
  icon: typeof Bell
}> = [
  {
    value: 'in_app',
    label: 'داخل التطبيق',
    description: 'يظهر في مركز الإشعارات',
    icon: Bell,
  },
  {
    value: 'push',
    label: 'Push',
    description: 'يصل إلى أجهزة المستخدمين',
    icon: Smartphone,
  },
  {
    value: 'both',
    label: 'كلاهما',
    description: 'داخل التطبيق + Push',
    icon: Radio,
  },
]

function getStatusClass(status: string): string {
  switch (status) {
    case 'completed':
      return 'wayn-notification-status wayn-notification-status--success'
    case 'partial':
      return 'wayn-notification-status wayn-notification-status--warning'
    case 'failed':
      return 'wayn-notification-status wayn-notification-status--danger'
    case 'in_progress':
      return 'wayn-notification-status wayn-notification-status--info'
    default:
      return 'wayn-notification-status wayn-notification-status--neutral'
  }
}

function StatusIcon({ status }: { status: string }) {
  if (status === 'completed') return <CheckCircle2 size={14} />
  if (status === 'failed') return <XCircle size={14} />
  if (status === 'in_progress') return <Clock3 size={14} />
  return <Radio size={14} />
}

/**
 * Admin notifications page.
 *
 * UI-only redesign:
 * - No API changes
 * - No backend changes
 * - No permission changes
 * - Existing notification sending/listing logic is preserved
 */
export function NotificationsPage() {
  const { hasPermission } = useAuth()
  const canSend = hasPermission(permissions.notificationsSend)

  const [page, setPage] = useState(1)
  const [limit] = useState(20)

  const {
    data,
    isPending,
    isFetching,
    isError,
    error,
  } = useAdminNotifications({ page, limit })

  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [channel, setChannel] =
    useState<NotificationChannel>('in_app')
  const [formError, setFormError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  const sendMutation = useSendAdminNotification()

  const pageStats = useMemo(() => {
    const items = data?.items ?? []

    return {
      total: items.length,
      completed: items.filter((item) => item.status === 'completed').length,
      pending: items.filter(
        (item) =>
          item.status === 'pending' ||
          item.status === 'in_progress',
      ).length,
      failed: items.filter((item) => item.status === 'failed').length,
    }
  }, [data])

  const selectedChannel = useMemo(
    () =>
      CHANNEL_OPTIONS.find((option) => option.value === channel) ??
      CHANNEL_OPTIONS[0],
    [channel],
  )

  const handleSubmit = useCallback(
    (event: FormEvent) => {
      event.preventDefault()

      setFormError(null)
      setSuccess(null)

      const trimmedTitle = title.trim()
      const trimmedBody = body.trim()

      if (
        trimmedTitle.length === 0 ||
        trimmedTitle.length > 200
      ) {
        setFormError('العنوان مطلوب ولا يتجاوز 200 حرف.')
        return
      }

      if (
        trimmedBody.length === 0 ||
        trimmedBody.length > 5000
      ) {
        setFormError('النص مطلوب ولا يتجاوز 5000 حرف.')
        return
      }

      sendMutation.mutate(
        {
          title: trimmedTitle,
          body: trimmedBody,
          channel,
          notification_type: 'broadcast',
        },
        {
          onSuccess: (notification) => {
            setSuccess(
              `تم إرسال الإشعار بنجاح إلى ${
                notification.delivered_count
              } من ${
                notification.total_recipients ??
                notification.delivered_count
              } مستلم.`,
            )

            setTitle('')
            setBody('')
            setPage(1)
          },
          onError: (err) => {
            setFormError(userFacingError(err))
          },
        },
      )
    },
    [title, body, channel, sendMutation],
  )

  return (
    <>
      <style>{`
        .wayn-notifications {
          direction: rtl;
          width: 100%;
          max-width: 1480px;
          margin: 0 auto;
          padding-bottom: 36px;
          color: #172033;
        }

        .wayn-notifications *,
        .wayn-notifications *::before,
        .wayn-notifications *::after {
          box-sizing: border-box;
        }

        .wayn-notifications-header {
          display: flex;
          align-items: flex-end;
          justify-content: space-between;
          gap: 24px;
          margin-bottom: 28px;
        }

        .wayn-notifications-header-main {
          display: flex;
          align-items: center;
          gap: 16px;
        }

        .wayn-notifications-header-icon {
          width: 52px;
          height: 52px;
          flex: 0 0 52px;
          display: grid;
          place-items: center;
          border-radius: 16px;
          background: linear-gradient(
            145deg,
            rgba(24, 169, 154, 0.16),
            rgba(24, 169, 154, 0.06)
          );
          color: #18a99a;
          border: 1px solid rgba(24, 169, 154, 0.12);
        }

        .wayn-notifications-header h2 {
          margin: 0 0 5px;
          font-size: 28px;
          line-height: 1.2;
          font-weight: 800;
          letter-spacing: -0.5px;
        }

        .wayn-notifications-header p {
          margin: 0;
          color: #718096;
          font-size: 14px;
          line-height: 1.7;
        }

        .wayn-notifications-live {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          padding: 9px 13px;
          border-radius: 999px;
          background: #f4fbfa;
          border: 1px solid #d9f1ee;
          color: #168d80;
          font-size: 12px;
          font-weight: 700;
          white-space: nowrap;
        }

        .wayn-notifications-live-dot {
          width: 7px;
          height: 7px;
          border-radius: 50%;
          background: #18a99a;
          box-shadow: 0 0 0 4px rgba(24, 169, 154, 0.10);
        }

        .wayn-notifications-card {
          background: #ffffff;
          border: 1px solid #e8edf3;
          border-radius: 22px;
          box-shadow:
            0 8px 30px rgba(23, 32, 51, 0.045),
            0 1px 2px rgba(23, 32, 51, 0.025);
        }

        .wayn-notifications-send-card {
          overflow: hidden;
          margin-bottom: 24px;
        }

        .wayn-notifications-send-layout {
          display: grid;
          grid-template-columns: minmax(0, 1.55fr) minmax(300px, 0.75fr);
          min-height: 430px;
        }

        .wayn-notifications-form {
          padding: 30px;
        }

        .wayn-notifications-section-heading {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 20px;
          margin-bottom: 24px;
        }

        .wayn-notifications-section-heading-main {
          display: flex;
          align-items: flex-start;
          gap: 13px;
        }

        .wayn-notifications-heading-icon {
          width: 40px;
          height: 40px;
          display: grid;
          place-items: center;
          flex: 0 0 40px;
          border-radius: 12px;
          background: #f1faf9;
          color: #18a99a;
        }

        .wayn-notifications-section-heading h3 {
          margin: 0 0 4px;
          font-size: 18px;
          font-weight: 800;
          color: #172033;
        }

        .wayn-notifications-section-heading p {
          margin: 0;
          color: #8a94a6;
          font-size: 13px;
          line-height: 1.6;
        }

        .wayn-notifications-broadcast-label {
          display: inline-flex;
          align-items: center;
          gap: 6px;
          padding: 7px 10px;
          border-radius: 8px;
          background: #f7f9fc;
          color: #687386;
          font-size: 11px;
          font-weight: 700;
          white-space: nowrap;
        }

        .wayn-notifications-field {
          margin-bottom: 19px;
        }

        .wayn-notifications-label-row {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
          margin-bottom: 8px;
        }

        .wayn-notifications-label-row label {
          color: #344054;
          font-size: 13px;
          font-weight: 750;
        }

        .wayn-notifications-counter {
          color: #9aa3b2;
          font-size: 11px;
          direction: ltr;
        }

        .wayn-notifications-input,
        .wayn-notifications-textarea {
          width: 100%;
          border: 1px solid #dfe5ec;
          border-radius: 12px;
          background: #fbfcfd;
          color: #172033;
          outline: none;
          font-family: inherit;
          font-size: 14px;
          transition:
            border-color 160ms ease,
            box-shadow 160ms ease,
            background 160ms ease;
        }

        .wayn-notifications-input {
          height: 46px;
          padding: 0 14px;
        }

        .wayn-notifications-textarea {
          min-height: 126px;
          padding: 13px 14px;
          resize: vertical;
          line-height: 1.8;
        }

        .wayn-notifications-input::placeholder,
        .wayn-notifications-textarea::placeholder {
          color: #a8b0bd;
        }

        .wayn-notifications-input:focus,
        .wayn-notifications-textarea:focus {
          background: #ffffff;
          border-color: rgba(24, 169, 154, 0.65);
          box-shadow: 0 0 0 4px rgba(24, 169, 154, 0.09);
        }

        .wayn-notifications-channel-grid {
          display: grid;
          grid-template-columns: repeat(3, minmax(0, 1fr));
          gap: 9px;
        }

        .wayn-notifications-channel {
          position: relative;
          display: flex;
          align-items: center;
          gap: 10px;
          min-height: 64px;
          padding: 10px 12px;
          border: 1px solid #e1e6ed;
          border-radius: 12px;
          background: #ffffff;
          color: #344054;
          cursor: pointer;
          text-align: right;
          transition:
            border-color 160ms ease,
            background 160ms ease,
            transform 160ms ease,
            box-shadow 160ms ease;
        }

        .wayn-notifications-channel:hover {
          border-color: #b8ddd8;
          transform: translateY(-1px);
        }

        .wayn-notifications-channel.active {
          border-color: rgba(24, 169, 154, 0.65);
          background: #f4fbfa;
          box-shadow: 0 5px 15px rgba(24, 169, 154, 0.07);
        }

        .wayn-notifications-channel-icon {
          width: 34px;
          height: 34px;
          flex: 0 0 34px;
          display: grid;
          place-items: center;
          border-radius: 9px;
          background: #f5f7fa;
          color: #7a8596;
        }

        .wayn-notifications-channel.active
          .wayn-notifications-channel-icon {
          background: rgba(24, 169, 154, 0.12);
          color: #18a99a;
        }

        .wayn-notifications-channel strong {
          display: block;
          margin-bottom: 2px;
          font-size: 12px;
          font-weight: 800;
        }

        .wayn-notifications-channel small {
          display: block;
          color: #8b95a5;
          font-size: 10px;
          line-height: 1.45;
        }

        .wayn-notifications-radio {
          position: absolute;
          top: 10px;
          left: 10px;
          width: 7px;
          height: 7px;
          border-radius: 50%;
          background: transparent;
        }

        .wayn-notifications-channel.active .wayn-notifications-radio {
          background: #18a99a;
          box-shadow: 0 0 0 3px rgba(24, 169, 154, 0.11);
        }

        .wayn-notifications-actions {
          display: flex;
          align-items: center;
          gap: 12px;
          margin-top: 22px;
        }

        .wayn-notifications-submit {
          min-width: 158px;
          height: 44px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 9px;
          border: 0;
          border-radius: 11px;
          background: #18a99a;
          color: #ffffff;
          font-family: inherit;
          font-size: 13px;
          font-weight: 800;
          cursor: pointer;
          box-shadow: 0 7px 18px rgba(24, 169, 154, 0.19);
          transition:
            transform 160ms ease,
            box-shadow 160ms ease,
            opacity 160ms ease;
        }

        .wayn-notifications-submit:hover:not(:disabled) {
          transform: translateY(-1px);
          box-shadow: 0 9px 22px rgba(24, 169, 154, 0.25);
        }

        .wayn-notifications-submit:disabled {
          cursor: not-allowed;
          opacity: 0.62;
        }

        .wayn-notifications-message {
          margin: 14px 0 0;
          padding: 11px 13px;
          border-radius: 10px;
          font-size: 12px;
          line-height: 1.6;
        }

        .wayn-notifications-message--error {
          color: #b42318;
          background: #fff5f4;
          border: 1px solid #fbd9d5;
        }

        .wayn-notifications-message--success {
          color: #16735f;
          background: #f0fbf7;
          border: 1px solid #ccefe3;
        }

        .wayn-notifications-preview {
          display: flex;
          flex-direction: column;
          justify-content: center;
          padding: 30px;
          background:
            radial-gradient(
              circle at 75% 15%,
              rgba(24, 169, 154, 0.11),
              transparent 30%
            ),
            #f8fafc;
          border-right: 1px solid #edf0f4;
        }

        .wayn-notifications-preview-label {
          display: flex;
          align-items: center;
          gap: 7px;
          margin-bottom: 14px;
          color: #7a8596;
          font-size: 11px;
          font-weight: 800;
        }

        .wayn-notifications-phone {
          width: 100%;
          max-width: 310px;
          margin: 0 auto;
          padding: 10px;
          border-radius: 25px;
          background: #172033;
          box-shadow:
            0 20px 40px rgba(23, 32, 51, 0.13),
            0 3px 8px rgba(23, 32, 51, 0.08);
        }

        .wayn-notifications-phone-screen {
          min-height: 275px;
          padding: 15px;
          border-radius: 18px;
          background: #f7f9fc;
        }

        .wayn-notifications-phone-top {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 18px;
          color: #8a94a6;
          font-size: 9px;
          font-weight: 700;
        }

        .wayn-notifications-preview-card {
          padding: 14px;
          border: 1px solid #e7ebf0;
          border-radius: 15px;
          background: #ffffff;
          box-shadow: 0 7px 20px rgba(23, 32, 51, 0.055);
        }

        .wayn-notifications-preview-card-top {
          display: flex;
          align-items: center;
          gap: 9px;
          margin-bottom: 11px;
        }

        .wayn-notifications-preview-avatar {
          width: 30px;
          height: 30px;
          display: grid;
          place-items: center;
          border-radius: 9px;
          background: #e8f8f6;
          color: #18a99a;
        }

        .wayn-notifications-preview-source {
          min-width: 0;
        }

        .wayn-notifications-preview-source strong {
          display: block;
          color: #344054;
          font-size: 10px;
          font-weight: 800;
        }

        .wayn-notifications-preview-source span {
          display: block;
          margin-top: 2px;
          color: #a0a8b5;
          font-size: 9px;
        }

        .wayn-notifications-preview-title {
          margin: 0 0 5px;
          color: #172033;
          font-size: 13px;
          font-weight: 800;
          line-height: 1.5;
          overflow-wrap: anywhere;
        }

        .wayn-notifications-preview-body {
          margin: 0;
          color: #687386;
          font-size: 11px;
          line-height: 1.75;
          white-space: pre-wrap;
          overflow-wrap: anywhere;
        }

        .wayn-notifications-preview-empty {
          color: #a0a8b5;
        }

        .wayn-notifications-preview-channel {
          display: inline-flex;
          align-items: center;
          gap: 5px;
          margin-top: 13px;
          padding: 5px 8px;
          border-radius: 7px;
          background: #f4f6f9;
          color: #788394;
          font-size: 9px;
          font-weight: 700;
        }

        .wayn-notifications-stats {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 14px;
          margin-bottom: 24px;
        }

        .wayn-notifications-stat {
          display: flex;
          align-items: center;
          gap: 13px;
          min-height: 86px;
          padding: 16px 18px;
          border: 1px solid #e8edf3;
          border-radius: 16px;
          background: #ffffff;
          box-shadow: 0 4px 16px rgba(23, 32, 51, 0.025);
        }

        .wayn-notifications-stat-icon {
          width: 42px;
          height: 42px;
          display: grid;
          place-items: center;
          flex: 0 0 42px;
          border-radius: 12px;
          background: #f4f6f9;
          color: #697586;
        }

        .wayn-notifications-stat--total
          .wayn-notifications-stat-icon {
          color: #18a99a;
          background: #eef9f7;
        }

        .wayn-notifications-stat--success
          .wayn-notifications-stat-icon {
          color: #16805f;
          background: #effaf5;
        }

        .wayn-notifications-stat--pending
          .wayn-notifications-stat-icon {
          color: #b7791f;
          background: #fff8eb;
        }

        .wayn-notifications-stat--failed
          .wayn-notifications-stat-icon {
          color: #c2413b;
          background: #fff3f2;
        }

        .wayn-notifications-stat-content {
          min-width: 0;
        }

        .wayn-notifications-stat-value {
          margin: 0 0 3px;
          color: #172033;
          font-size: 21px;
          font-weight: 850;
          line-height: 1;
        }

        .wayn-notifications-stat-label {
          margin: 0;
          color: #8a94a6;
          font-size: 11px;
          font-weight: 650;
        }

        .wayn-notifications-history {
          overflow: hidden;
        }

        .wayn-notifications-history-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 18px;
          padding: 23px 25px;
          border-bottom: 1px solid #edf0f4;
        }

        .wayn-notifications-history-title {
          display: flex;
          align-items: center;
          gap: 11px;
        }

        .wayn-notifications-history-title-icon {
          width: 37px;
          height: 37px;
          display: grid;
          place-items: center;
          border-radius: 10px;
          background: #f1faf9;
          color: #18a99a;
        }

        .wayn-notifications-history-title h3 {
          margin: 0 0 3px;
          color: #172033;
          font-size: 16px;
          font-weight: 800;
        }

        .wayn-notifications-history-title p {
          margin: 0;
          color: #929baa;
          font-size: 11px;
        }

        .wayn-notifications-refreshing {
          color: #18a99a;
          font-size: 11px;
          font-weight: 700;
        }

        .wayn-notifications-table-wrap {
          width: 100%;
          overflow-x: auto;
        }

        .wayn-notifications-table {
          width: 100%;
          min-width: 920px;
          border-collapse: collapse;
        }

        .wayn-notifications-table th {
          padding: 13px 18px;
          background: #fafbfc;
          border-bottom: 1px solid #edf0f4;
          color: #8a94a6;
          font-size: 10px;
          font-weight: 800;
          text-align: right;
          white-space: nowrap;
        }

        .wayn-notifications-table td {
          padding: 16px 18px;
          border-bottom: 1px solid #f0f2f5;
          color: #475467;
          font-size: 12px;
          vertical-align: middle;
          white-space: nowrap;
        }

        .wayn-notifications-table tbody tr {
          transition: background 140ms ease;
        }

        .wayn-notifications-table tbody tr:hover {
          background: #fbfdfd;
        }

        .wayn-notifications-table tbody tr:last-child td {
          border-bottom: 0;
        }

        .wayn-notifications-title-cell {
          max-width: 270px;
          overflow: hidden;
          text-overflow: ellipsis;
          color: #273246 !important;
          font-weight: 750;
        }

        .wayn-notifications-channel-badge,
        .wayn-notification-status {
          display: inline-flex;
          align-items: center;
          gap: 5px;
          min-height: 27px;
          padding: 5px 9px;
          border-radius: 8px;
          font-size: 10px;
          font-weight: 750;
        }

        .wayn-notifications-channel-badge {
          background: #f4f6f9;
          color: #697586;
        }

        .wayn-notifications-channel-badge--push {
          background: #eef7ff;
          color: #2876b9;
        }

        .wayn-notifications-channel-badge--both {
          background: #f1faf9;
          color: #168d80;
        }

        .wayn-notification-status--success {
          background: #effaf5;
          color: #167a5b;
        }

        .wayn-notification-status--warning {
          background: #fff8eb;
          color: #a96d18;
        }

        .wayn-notification-status--danger {
          background: #fff3f2;
          color: #c2413b;
        }

        .wayn-notification-status--info {
          background: #eef7ff;
          color: #2876b9;
        }

        .wayn-notification-status--neutral {
          background: #f4f6f9;
          color: #697586;
        }

        .wayn-notifications-number {
          color: #344054;
          font-weight: 750;
          direction: ltr;
        }

        .wayn-notifications-date {
          color: #7d8797;
          direction: rtl;
        }

        .wayn-notifications-empty {
          padding: 55px 20px !important;
          text-align: center !important;
          color: #98a2b3 !important;
        }

        .wayn-notifications-empty-icon {
          width: 46px;
          height: 46px;
          margin: 0 auto 11px;
          display: grid;
          place-items: center;
          border-radius: 13px;
          background: #f5f7fa;
          color: #98a2b3;
        }

        .wayn-notifications-empty strong {
          display: block;
          margin-bottom: 4px;
          color: #667085;
          font-size: 12px;
        }

        .wayn-notifications-empty span {
          font-size: 11px;
        }

        .wayn-notifications-footer {
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          padding: 17px 22px;
          border-top: 1px solid #edf0f4;
          background: #fcfdfd;
        }

        .wayn-notifications-pagination-info {
          color: #8a94a6;
          font-size: 11px;
        }

        .wayn-notifications-pagination {
          display: flex;
          align-items: center;
          gap: 8px;
        }

        .wayn-notifications-page-btn {
          height: 35px;
          padding: 0 13px;
          border: 1px solid #e0e5eb;
          border-radius: 9px;
          background: #ffffff;
          color: #596579;
          font-family: inherit;
          font-size: 11px;
          font-weight: 700;
          cursor: pointer;
          transition:
            border-color 140ms ease,
            background 140ms ease,
            color 140ms ease;
        }

        .wayn-notifications-page-btn:hover:not(:disabled) {
          border-color: #b7ddd8;
          background: #f7fcfb;
          color: #168d80;
        }

        .wayn-notifications-page-btn:disabled {
          cursor: not-allowed;
          opacity: 0.42;
        }

        .wayn-notifications-loading {
          padding: 55px 20px;
          text-align: center;
          color: #8a94a6;
          font-size: 12px;
        }

        .wayn-notifications-error {
          margin: 20px 22px;
          padding: 13px 15px;
          border-radius: 11px;
          background: #fff5f4;
          border: 1px solid #fbd9d5;
          color: #b42318;
          font-size: 12px;
        }

        @media (max-width: 1100px) {
          .wayn-notifications-send-layout {
            grid-template-columns: 1fr;
          }

          .wayn-notifications-preview {
            border-right: 0;
            border-top: 1px solid #edf0f4;
          }

          .wayn-notifications-phone {
            max-width: 360px;
          }
        }

        @media (max-width: 800px) {
          .wayn-notifications {
            padding-bottom: 24px;
          }

          .wayn-notifications-header {
            align-items: flex-start;
            flex-direction: column;
          }

          .wayn-notifications-stats {
            grid-template-columns: repeat(2, minmax(0, 1fr));
          }

          .wayn-notifications-form,
          .wayn-notifications-preview {
            padding: 22px;
          }

          .wayn-notifications-channel-grid {
            grid-template-columns: 1fr;
          }

          .wayn-notifications-section-heading {
            flex-direction: column;
          }

          .wayn-notifications-footer {
            align-items: flex-start;
            flex-direction: column;
          }

          .wayn-notifications-pagination {
            width: 100%;
            justify-content: space-between;
          }
        }

        @media (max-width: 520px) {
          .wayn-notifications-header-main {
            align-items: flex-start;
          }

          .wayn-notifications-header h2 {
            font-size: 23px;
          }

          .wayn-notifications-header-icon {
            width: 46px;
            height: 46px;
            flex-basis: 46px;
          }

          .wayn-notifications-stats {
            grid-template-columns: 1fr;
          }

          .wayn-notifications-actions {
            flex-direction: column;
            align-items: stretch;
          }

          .wayn-notifications-submit {
            width: 100%;
          }
        }
      `}</style>

      <div className="wayn-notifications">
        <header className="wayn-notifications-header">
          <div className="wayn-notifications-header-main">
            <div className="wayn-notifications-header-icon">
              <Bell size={24} strokeWidth={1.9} />
            </div>

            <div>
              <h2>الإشعارات</h2>
              <p>
                أرسل رسائل للمستخدمين وتابع حالة الإشعارات المرسلة.
              </p>
            </div>
          </div>

          <div className="wayn-notifications-live">
            <span className="wayn-notifications-live-dot" />
            نظام الإشعارات متصل
          </div>
        </header>

        {canSend && (
          <section className="wayn-notifications-card wayn-notifications-send-card">
            <div className="wayn-notifications-send-layout">
              <div className="wayn-notifications-form">
                <div className="wayn-notifications-section-heading">
                  <div className="wayn-notifications-section-heading-main">
                    <div className="wayn-notifications-heading-icon">
                      <Send size={18} />
                    </div>

                    <div>
                      <h3>إرسال إشعار جديد</h3>
                      <p>
                        أنشئ رسالة وأرسلها للمستخدمين عبر القناة المناسبة.
                      </p>
                    </div>
                  </div>

                  <div className="wayn-notifications-broadcast-label">
                    <Users size={13} />
                    إرسال جماعي
                  </div>
                </div>

                <form onSubmit={handleSubmit} noValidate>
                  <div className="wayn-notifications-field">
                    <div className="wayn-notifications-label-row">
                      <label htmlFor="notification-title">
                        عنوان الإشعار
                      </label>

                      <span className="wayn-notifications-counter">
                        {title.length}/200
                      </span>
                    </div>

                    <input
                      id="notification-title"
                      className="wayn-notifications-input"
                      type="text"
                      value={title}
                      maxLength={200}
                      onChange={(event) =>
                        setTitle(event.target.value)
                      }
                      placeholder="مثال: تحديث جديد في WAYN"
                    />
                  </div>

                  <div className="wayn-notifications-field">
                    <div className="wayn-notifications-label-row">
                      <label htmlFor="notification-body">
                        محتوى الإشعار
                      </label>

                      <span className="wayn-notifications-counter">
                        {body.length}/5000
                      </span>
                    </div>

                    <textarea
                      id="notification-body"
                      className="wayn-notifications-textarea"
                      value={body}
                      maxLength={5000}
                      rows={5}
                      onChange={(event) =>
                        setBody(event.target.value)
                      }
                      placeholder="اكتب الرسالة التي تريد إيصالها للمستخدمين..."
                    />
                  </div>

                  <div className="wayn-notifications-field">
                    <div className="wayn-notifications-label-row">
                      <label>قناة الإرسال</label>
                    </div>

                    <div className="wayn-notifications-channel-grid">
                      {CHANNEL_OPTIONS.map((option) => {
                        const Icon = option.icon
                        const active = channel === option.value

                        return (
                          <button
                            key={option.value}
                            type="button"
                            className={`wayn-notifications-channel${
                              active ? ' active' : ''
                            }`}
                            onClick={() =>
                              setChannel(option.value)
                            }
                            aria-pressed={active}
                          >
                            <span className="wayn-notifications-channel-icon">
                              <Icon size={16} />
                            </span>

                            <span>
                              <strong>{option.label}</strong>
                              <small>{option.description}</small>
                            </span>

                            <span className="wayn-notifications-radio" />
                          </button>
                        )
                      })}
                    </div>
                  </div>

                  {formError && (
                    <p
                      className="wayn-notifications-message wayn-notifications-message--error"
                      role="alert"
                    >
                      {formError}
                    </p>
                  )}

                  {success && (
                    <p
                      className="wayn-notifications-message wayn-notifications-message--success"
                      role="status"
                    >
                      {success}
                    </p>
                  )}

                  <div className="wayn-notifications-actions">
                    <button
                      type="submit"
                      className="wayn-notifications-submit"
                      disabled={sendMutation.isPending}
                    >
                      <Send size={15} />

                      {sendMutation.isPending
                        ? 'جارٍ الإرسال…'
                        : 'إرسال الإشعار'}
                    </button>
                  </div>
                </form>
              </div>

              <aside className="wayn-notifications-preview">
                <div className="wayn-notifications-preview-label">
                  <Smartphone size={13} />
                  معاينة الإشعار
                </div>

                <div className="wayn-notifications-phone">
                  <div className="wayn-notifications-phone-screen">
                    <div className="wayn-notifications-phone-top">
                      <span>WAYN</span>
                      <span>الآن</span>
                    </div>

                    <div className="wayn-notifications-preview-card">
                      <div className="wayn-notifications-preview-card-top">
                        <div className="wayn-notifications-preview-avatar">
                          <Bell size={15} />
                        </div>

                        <div className="wayn-notifications-preview-source">
                          <strong>WAYN</strong>
                          <span>إشعار جديد</span>
                        </div>
                      </div>

                      <h4 className="wayn-notifications-preview-title">
                        {title.trim() || (
                          <span className="wayn-notifications-preview-empty">
                            عنوان الإشعار
                          </span>
                        )}
                      </h4>

                      <p className="wayn-notifications-preview-body">
                        {body.trim() || (
                          <span className="wayn-notifications-preview-empty">
                            سيظهر نص الإشعار هنا...
                          </span>
                        )}
                      </p>

                      <div className="wayn-notifications-preview-channel">
                        {(() => {
                          const Icon = selectedChannel.icon
                          return <Icon size={10} />
                        })()}
                        {selectedChannel.label}
                      </div>
                    </div>
                  </div>
                </div>
              </aside>
            </div>
          </section>
        )}

        <div className="wayn-notifications-stats">
          <div className="wayn-notifications-stat wayn-notifications-stat--total">
            <div className="wayn-notifications-stat-icon">
              <LayoutGrid size={19} />
            </div>

            <div className="wayn-notifications-stat-content">
              <p className="wayn-notifications-stat-value">
                {pageStats.total}
              </p>
              <p className="wayn-notifications-stat-label">
                الإشعارات في الصفحة الحالية
              </p>
            </div>
          </div>

          <div className="wayn-notifications-stat wayn-notifications-stat--success">
            <div className="wayn-notifications-stat-icon">
              <CheckCircle2 size={19} />
            </div>

            <div className="wayn-notifications-stat-content">
              <p className="wayn-notifications-stat-value">
                {pageStats.completed}
              </p>
              <p className="wayn-notifications-stat-label">
                مكتملة
              </p>
            </div>
          </div>

          <div className="wayn-notifications-stat wayn-notifications-stat--pending">
            <div className="wayn-notifications-stat-icon">
              <Clock3 size={19} />
            </div>

            <div className="wayn-notifications-stat-content">
              <p className="wayn-notifications-stat-value">
                {pageStats.pending}
              </p>
              <p className="wayn-notifications-stat-label">
                قيد التنفيذ
              </p>
            </div>
          </div>

          <div className="wayn-notifications-stat wayn-notifications-stat--failed">
            <div className="wayn-notifications-stat-icon">
              <XCircle size={19} />
            </div>

            <div className="wayn-notifications-stat-content">
              <p className="wayn-notifications-stat-value">
                {pageStats.failed}
              </p>
              <p className="wayn-notifications-stat-label">
                فاشلة
              </p>
            </div>
          </div>
        </div>

        <section className="wayn-notifications-card wayn-notifications-history">
          <div className="wayn-notifications-history-header">
            <div className="wayn-notifications-history-title">
              <div className="wayn-notifications-history-title-icon">
                <FileText size={17} />
              </div>

              <div>
                <h3>سجل الإشعارات</h3>
                <p>
                  جميع عمليات الإرسال الأخيرة وحالتها.
                </p>
              </div>
            </div>

            {isFetching && !isPending && (
              <span className="wayn-notifications-refreshing">
                جارٍ التحديث…
              </span>
            )}
          </div>

          {isPending && (
            <div className="wayn-notifications-loading">
              جارٍ تحميل سجل الإشعارات…
            </div>
          )}

          {isError && (
            <div
              className="wayn-notifications-error"
              role="alert"
            >
              {userFacingError(error)}
            </div>
          )}

          {data && (
            <>
              <div className="wayn-notifications-table-wrap">
                <table className="wayn-notifications-table">
                  <thead>
                    <tr>
                      <th>الإشعار</th>
                      <th>القناة</th>
                      <th>الحالة</th>
                      <th>المستلمون</th>
                      <th>تم الوصول</th>
                      <th>فشل</th>
                      <th>الإنشاء</th>
                      <th>الإرسال</th>
                    </tr>
                  </thead>

                  <tbody>
                    {data.items.map((item) => {
                      const channelClass =
                        item.channel === 'push'
                          ? 'wayn-notifications-channel-badge wayn-notifications-channel-badge--push'
                          : item.channel === 'both'
                            ? 'wayn-notifications-channel-badge wayn-notifications-channel-badge--both'
                            : 'wayn-notifications-channel-badge'

                      return (
                        <tr key={item.id}>
                          <td
                            className="wayn-notifications-title-cell"
                            title={item.title}
                          >
                            {item.title}
                          </td>

                          <td>
                            <span className={channelClass}>
                              {CHANNEL_LABELS[item.channel] ??
                                item.channel}
                            </span>
                          </td>

                          <td>
                            <span
                              className={getStatusClass(
                                item.status,
                              )}
                            >
                              <StatusIcon status={item.status} />
                              {STATUS_LABELS[item.status] ??
                                item.status}
                            </span>
                          </td>

                          <td>
                            <span className="wayn-notifications-number">
                              {item.total_recipients ?? '—'}
                            </span>
                          </td>

                          <td>
                            <span className="wayn-notifications-number">
                              {item.delivered_count}
                            </span>
                          </td>

                          <td>
                            <span className="wayn-notifications-number">
                              {item.failed_count}
                            </span>
                          </td>

                          <td>
                            <span className="wayn-notifications-date">
                              {formatDate(item.created_at)}
                            </span>
                          </td>

                          <td>
                            <span className="wayn-notifications-date">
                              {formatDate(item.sent_at)}
                            </span>
                          </td>
                        </tr>
                      )
                    })}

                    {data.items.length === 0 && (
                      <tr>
                        <td
                          colSpan={8}
                          className="wayn-notifications-empty"
                        >
                          <div className="wayn-notifications-empty-icon">
                            <Bell size={20} />
                          </div>

                          <strong>
                            لا توجد إشعارات بعد
                          </strong>

                          <span>
                            ستظهر الإشعارات المرسلة هنا.
                          </span>
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>

              <div className="wayn-notifications-footer">
                <span className="wayn-notifications-pagination-info">
                  صفحة {data.page} من {data.pages || 1}
                  {' · '}
                  {data.total} إشعار
                  {isFetching ? ' · جارٍ التحديث…' : ''}
                </span>

                <div className="wayn-notifications-pagination">
                  <button
                    type="button"
                    className="wayn-notifications-page-btn"
                    disabled={page <= 1}
                    onClick={() =>
                      setPage((current) => current - 1)
                    }
                  >
                    السابق
                  </button>

                  <button
                    type="button"
                    className="wayn-notifications-page-btn"
                    disabled={
                      page >= (data.pages || 1)
                    }
                    onClick={() =>
                      setPage((current) => current + 1)
                    }
                  >
                    التالي
                  </button>
                </div>
              </div>
            </>
          )}
        </section>
      </div>
    </>
  )
}
