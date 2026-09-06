import { useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ArrowRight, CheckCircle2, RotateCcw, ShieldAlert, UserRound } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAuth } from '../../auth/useAuth'
import { formatDate } from '../../lib/format'
import { useRegularUser } from '../../hooks/useRegularUsers'
import { useRegularUserStatusMutation } from '../../hooks/useRegularUserMutations'
import { permissions } from '../../permissions/permissionNames'
import {
  ACCOUNT_STATUS_LABELS,
  RESTRICTED_STATUSES,
  type AccountStatus,
  type RegularUserStatusUpdatePayload,
} from '../../types/regularUser'
import './regular-users.css'

export function RegularUserDetailsPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { hasPermission } = useAuth()
  const { data: user, isPending, isError, error, refetch } = useRegularUser(id)

  if (!id) return null

  if (isPending) {
    return (
      <div className="rusers-page">
        <div className="card state-card" aria-busy="true">
          <p>جارٍ تحميل بيانات المستخدم…</p>
        </div>
      </div>
    )
  }

  if (isError) {
    return (
      <div className="rusers-page">
        <div className="card state-card" role="alert">
          <ShieldAlert size={24} aria-hidden />
          <p>{userFacingError(error, 'تعذر تحميل بيانات المستخدم.')}</p>
          <div className="state-actions">
            <button type="button" className="btn btn-primary" onClick={() => void refetch()}>
              <RotateCcw size={16} /> إعادة المحاولة
            </button>
            <Link to="/regular-users" className="btn btn-ghost">
              العودة إلى القائمة
            </Link>
          </div>
        </div>
      </div>
    )
  }

  if (!user) {
    return (
      <div className="rusers-page">
        <div className="card state-card">
          <UserRound size={24} aria-hidden />
          <p>المستخدم غير موجود.</p>
          <Link to="/regular-users" className="btn btn-ghost">
            <ArrowRight size={16} /> العودة إلى القائمة
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="rusers-page">
      <header className="rusers-header">
        <div>
          <button type="button" className="btn btn-ghost btn-back" onClick={() => navigate(-1)}>
            <ArrowRight size={16} /> رجوع
          </button>
          <h2>{user.full_name}</h2>
          <p className="muted">@{user.username} · {user.email}</p>
        </div>
      </header>

      <div className="card ruser-details">
        <InfoRow label="حالة الحساب" value={ACCOUNT_STATUS_LABELS[user.account_status]} />
        <InfoRow label="النشاط" value={user.is_active ? 'نشط' : 'معطل'} />
        <InfoRow label="التوثيق" value={user.is_verified ? 'موثّق' : 'غير موثّق'} />
        <InfoRow label="الهاتف" value={user.phone ?? '—'} />
        <InfoRow label="النقاط" value={String(user.points)} />
        <InfoRow label="تاريخ الإنشاء" value={formatDate(user.created_at)} />
        <InfoRow label="آخر دخول" value={formatDate(user.last_login_at)} />
        <InfoRow label="المعرّف" value={user.id} mono />
      </div>

      <StatusManager
        userId={user.id}
        currentStatus={user.account_status}
        currentActive={user.is_active}
        canUpdate={hasPermission(permissions.usersUpdate)}
        canDisable={hasPermission(permissions.usersDisable)}
      />
    </div>
  )
}

function InfoRow({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="info-row">
      <span className="info-label">{label}</span>
      <span className={mono ? 'info-value mono' : 'info-value'}>{value}</span>
    </div>
  )
}

function StatusManager({
  userId,
  currentStatus,
  currentActive,
  canUpdate,
  canDisable,
}: {
  userId: string
  currentStatus: AccountStatus
  currentActive: boolean
  canUpdate: boolean
  canDisable: boolean
}) {
  const [status, setStatus] = useState<AccountStatus>(currentStatus)
  const [active, setActive] = useState<boolean>(currentActive)
  const [reason, setReason] = useState('')
  const [pendingPayload, setPendingPayload] = useState<RegularUserStatusUpdatePayload | null>(null)

  const restricted = active === false || RESTRICTED_STATUSES.has(status)
  const hasChoiceChanged = status !== currentStatus || active !== currentActive
  const allowed = restricted ? canDisable : canUpdate
  const needsOtherPermission = hasChoiceChanged && restricted && !canDisable && canUpdate

  const payload = useMemo<RegularUserStatusUpdatePayload>(() => {
    const result: RegularUserStatusUpdatePayload = {}
    if (status !== currentStatus) result.account_status = status
    if (active !== currentActive) result.is_active = active
    const trimmed = reason.trim()
    if (trimmed !== '') result.status_reason = trimmed
    return result
  }, [status, active, reason, currentStatus, currentActive])

  return (
    <section className="card ruser-status">
      <h3>إدارة حالة الحساب</h3>

      {needsOtherPermission && (
        <p className="perm-note">
          تغيير الحالة إلى قيمة مقيّدة (تعطيل / إخفاء / إيقاف / حظر) يتطلب صلاحية{' '}
          <code>users.disable</code> غير متوفرة لحسابك.
        </p>
      )}

      <div className="status-grid">
        <label className="filter-field">
          <span className="filter-label">حالة الحساب</span>
          <select value={status} onChange={(event) => setStatus(event.target.value as AccountStatus)}>
            {Object.entries(ACCOUNT_STATUS_LABELS).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">الحساب نشط؟</span>
          <select
            value={active ? 'true' : 'false'}
            onChange={(event) => setActive(event.target.value === 'true')}
          >
            <option value="true">نشط</option>
            <option value="false">معطل</option>
          </select>
        </label>
        <label className="filter-field status-reason">
          <span className="filter-label">سبب التغيير (اختياري)</span>
          <input
            type="text"
            value={reason}
            maxLength={255}
            placeholder="سبب داخلي يُسجَّل مع العملية"
            onChange={(event) => setReason(event.target.value)}
          />
        </label>
      </div>

      {restricted && (
        <p className="warn-note">
          <ShieldAlert size={14} aria-hidden /> هذه العملية مقيّدة وتتطلب صلاحية{' '}
          <code>users.disable</code>، وستُنهي جلسة المستخدم في التطبيق فورًا (token_version).
        </p>
      )}

      <div className="status-actions">
        <button
          type="button"
          className="btn btn-primary"
          disabled={!hasChoiceChanged || !allowed || Object.keys(payload).length === 0}
          onClick={() => setPendingPayload(payload)}
        >
          <CheckCircle2 size={16} /> حفظ التغييرات
        </button>
        {!hasChoiceChanged && <span className="cell-muted">لا توجد تغييرات لحفظها.</span>}
      </div>

      {pendingPayload && (
        <StatusConfirmModal
          userId={userId}
          payload={pendingPayload}
          onClose={() => setPendingPayload(null)}
        />
      )}
    </section>
  )
}

/** Confirmation dialog; the actual PATCH happens only after explicit confirm. */
function StatusConfirmModal({
  userId,
  payload,
  onClose,
}: {
  userId: string
  payload: RegularUserStatusUpdatePayload
  onClose: () => void
}) {
  const mutation = useRegularUserStatusMutation(userId)

  const summary = useMemo(() => {
    const parts: string[] = []
    if (payload.account_status) parts.push(`حالة الحساب: ${ACCOUNT_STATUS_LABELS[payload.account_status]}`)
    if (payload.is_active !== undefined) parts.push(`النشاط: ${payload.is_active ? 'نشط' : 'معطل'}`)
    if (payload.status_reason) parts.push(`السبب: ${payload.status_reason}`)
    return parts.join(' · ')
  }, [payload])

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h4>تأكيد تغيير حالة الحساب</h4>
        <p className="modal-summary">{summary}</p>
        <p className="warn-note">
          <ShieldAlert size={14} aria-hidden /> تغيير الحالة يُنهي جلسة المستخدم في التطبيق فورًا
          (token_version).
        </p>
        {mutation.isError && (
          <p className="error-note" role="alert">
            {userFacingError(mutation.error)}
          </p>
        )}
        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-primary"
            disabled={mutation.isPending}
            onClick={() => mutation.mutate(payload, { onSuccess: onClose })}
          >
            {mutation.isPending ? 'جارٍ الحفظ…' : 'تأكيد'}
          </button>
          <button type="button" className="btn btn-ghost" disabled={mutation.isPending} onClick={onClose}>
            إلغاء
          </button>
        </div>
      </div>
    </div>
  )
}

