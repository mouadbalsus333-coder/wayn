import { Ban, CheckCircle2, Clock, Search, Star, XCircle } from 'lucide-react'
import type {
  AdminActionLogRead,
  AppealStatus,
  ModerationPostPreview,
  ModerationStats,
} from '../../types/moderation'

export const APPEAL_STATUS_LABELS: Record<AppealStatus, string> = {
  PENDING: 'جديدة',
  UNDER_REVIEW: 'قيد المراجعة',
  RESOLVED: 'تمت معالجتها',
  REJECTED: 'مرفوضة',
  CANCELLED: 'ملغاة',
}

export const APPEAL_TYPE_LABELS: Record<string, string> = {
  INCORRECT_RATING: 'تقييم غير صحيح',
  MISLEADING_RATING: 'تقييم مضلل',
  OTHER: 'أخرى',
}

export const REPORT_CATEGORY_LABELS: Record<string, string> = {
  ABUSE: 'سوء وإساءة',
  INAPPROPRIATE_CONTENT: 'محتوى غير مناسب',
  SPAM: 'إعلانات / مزعج',
  FALSE_INFO: 'معلومات خاطئة',
  OTHER: 'أخرى',
}

export const POST_ACTION_LABELS: Record<string, string> = {
  NONE: '—',
  DELETE_POST: 'تم حذف المنشور',
  HIDE_POST: 'تم إخفاء المنشور',
  LEAVE_AS_IS: 'بقي المنشور كما هو',
}

const STATUS_BADGE_CLASS: Record<string, string> = {
  PENDING: 'badge-pending',
  UNDER_REVIEW: 'badge-review',
  RESOLVED: 'badge-resolved',
  REJECTED: 'badge-rejected',
  CANCELLED: 'badge-cancelled',
}

export function StatusBadge({ status }: { status: string }) {
  return (
    <span className={`badge ${STATUS_BADGE_CLASS[status] ?? 'badge-cancelled'}`}>
      {APPEAL_STATUS_LABELS[status as AppealStatus] ?? status}
    </span>
  )
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—'

  const date = new Date(value)

  if (Number.isNaN(date.getTime())) {
    return value
  }

  return date.toLocaleString('ar', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function StatsRow({
  stats,
}: {
  stats: ModerationStats | undefined
}) {
  const cards = [
    {
      label: 'الإجمالي',
      value: stats?.total ?? 0,
      cls: 'stat-total',
      icon: Search,
    },
    {
      label: 'جديدة',
      value: stats?.pending ?? 0,
      cls: 'stat-pending',
      icon: Clock,
    },
    {
      label: 'قيد المراجعة',
      value: stats?.under_review ?? 0,
      cls: 'stat-review',
      icon: Search,
    },
    {
      label: 'تمت معالجتها',
      value: stats?.resolved ?? 0,
      cls: 'stat-resolved',
      icon: CheckCircle2,
    },
    {
      label: 'مرفوضة',
      value: stats?.rejected ?? 0,
      cls: 'stat-rejected',
      icon: XCircle,
    },
    {
      label: 'ملغاة',
      value: stats?.cancelled ?? 0,
      cls: 'stat-cancelled',
      icon: Ban,
    },
  ]

  return (
    <div className="moderation-stats">
      {cards.map((card) => (
        <div
          key={card.label}
          className={`card stat-card ${card.cls}`}
        >
          <div className="stat-card-icon">
            <card.icon size={17} aria-hidden />
          </div>

          <div className="stat-card-content">
            <strong>{card.value}</strong>
            <span>{card.label}</span>
          </div>
        </div>
      ))}
    </div>
  )
}

const ACTION_LABELS: Record<string, string> = {
  STATUS_CHANGED: 'تغيير الحالة',
  POST_DELETED: 'حذف المنشور',
  POST_HIDDEN: 'إخفاء المنشور',
}

/** Read-only snapshot of the moderated post (data already provided by the backend). */
export function PostPreviewCard({
  post,
}: {
  post: ModerationPostPreview | null
}) {
  if (!post) {
    return (
      <div className="card post-preview">
        <div className="section-heading">
          <h3>محتوى المنشور</h3>
        </div>

        <p className="cell-muted">
          المنشور غير متوفر، وقد يكون محذوفًا نهائيًا.
        </p>
      </div>
    )
  }

  const imageBase = (
    import.meta.env.VITE_API_URL || 'http://localhost:8000'
  ).replace(/\/$/, '')

  const imageUrl = post.image_url
    ? post.image_url.startsWith('http')
      ? post.image_url
      : post.image_url.startsWith('/api')
        ? `${imageBase}${post.image_url}`
        : `${imageBase}/api/v1/media/${post.image_url}`
    : null

  const stateLabel =
    post.visibility_state === 'ACTIVE'
      ? 'ظاهر'
      : post.visibility_state === 'HIDDEN'
        ? 'مخفي'
        : post.visibility_state === 'DELETED'
          ? 'محذوف'
          : (post.visibility_state ?? '—')

  return (
    <div className="card post-preview">
      <div className="section-heading">
        <div>
          <span className="section-kicker">المحتوى المرتبط</span>
          <h3>المنشور محل المراجعة</h3>
        </div>
      </div>

      <div className="post-preview-body">
        {imageUrl && (
          <img
            src={imageUrl}
            alt="صورة المنشور"
            className="post-image"
          />
        )}

        {post.rating != null && (
          <p className="rating-cell">
            <Star
              size={15}
              className="star"
              aria-hidden
            />
            تقييم المنشور: {String(post.rating)}
          </p>
        )}

        {post.text && (
          <p className="post-body">
            {post.text}
          </p>
        )}

        <div className="post-meta">
          <span>
            الكاتب: {post.author_name ?? '—'}
            {post.author_username
              ? ` (@${post.author_username})`
              : ''}
          </span>

          {post.place_name && (
            <span>
              المكان: {post.place_name}
              {post.place_city
                ? ` - ${post.place_city}`
                : ''}
            </span>
          )}

          <span>
            التفاعل: {post.likes_count} إعجاب ·{' '}
            {post.comments_count} تعليق ·{' '}
            {post.saves_count} حفظ
          </span>

          <span>
            الحالة: {stateLabel}
          </span>
        </div>
      </div>
    </div>
  )
}

/** Internal audit trail — visible to admins only. */
export function ActionsTrail({
  actions,
}: {
  actions: AdminActionLogRead[]
}) {
  return (
    <div className="card actions-trail">
      <div className="section-heading">
        <div>
          <span className="section-kicker">سجل داخلي</span>
          <h3>سجل الإجراءات</h3>
        </div>
      </div>

      {!actions.length ? (
        <p className="cell-muted">
          لا توجد إجراءات مسجلة بعد.
        </p>
      ) : (
        <ul className="actions-list">
          {actions.map((entry) => (
            <li key={entry.id}>
              <div className="action-head">
                <strong>
                  {ACTION_LABELS[entry.action] ?? entry.action}
                </strong>

                <span className="cell-muted">
                  {formatDate(entry.created_at)}
                </span>
              </div>

              <p className="cell-muted">
                بواسطة: {entry.admin_email ?? '—'}
              </p>

              {entry.notes && (
                <p className="action-notes">
                  {entry.notes}
                </p>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}