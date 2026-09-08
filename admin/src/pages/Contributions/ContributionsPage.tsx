import { useState } from 'react'
import {
  CheckCircle2,
  ClipboardCheck,
  RotateCcw,
  ShieldAlert,
  XCircle,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAuth } from '../../auth/useAuth'
import { useContributions } from '../../hooks/useContributions'
import { useApproveContributionMutation, useRejectContributionMutation } from '../../hooks/useContributionMutations'
import { permissions } from '../../permissions/permissionNames'
import { formatDate } from '../../lib/format'
import type {
  ContributionRead,
  ContributionStatus,
  ContributionType,
} from '../../types/contribution'
import './contributions.css'

const PAGE_SIZE = 20

const TYPE_LABELS: Record<ContributionType, string> = {
  CREATE_PLACE: 'إنشاء مكان',
  UPDATE_PLACE: 'تعديل مكان',
  ADD_IMAGE: 'إضافة صورة',
  UPDATE_INFORMATION: 'تحديث معلومات',
  VERIFY_PLACE: 'التحقق من مكان',
}

const STATUS_LABELS: Record<ContributionStatus, string> = {
  PENDING: 'قيد الانتظار',
  APPROVED: 'معتمدة',
  REJECTED: 'مرفوضة',
  CANCELLED: 'ملغاة',
}

function statusBadge(status: ContributionStatus) {
  switch (status) {
    case 'APPROVED':
      return <span className="badge badge-green">{STATUS_LABELS[status]}</span>
    case 'REJECTED':
      return <span className="badge badge-red">{STATUS_LABELS[status]}</span>
    case 'PENDING':
      return <span className="badge badge-amber">{STATUS_LABELS[status]}</span>
    default:
      return <span className="badge badge-muted">{STATUS_LABELS[status]}</span>
  }
}
export function ContributionsPage() {
  const { hasPermission } = useAuth()
  const canApprove = hasPermission(permissions.contributionsApprove)
  const canReject = hasPermission(permissions.contributionsReject)

  const [page, setPage] = useState(1)
  const [status, setStatus] = useState<ContributionStatus | undefined>(undefined)
  const [type, setType] = useState<ContributionType | undefined>(undefined)
  const [pendingApprove, setPendingApprove] = useState<ContributionRead | null>(null)
  const [pendingReject, setPendingReject] = useState<ContributionRead | null>(null)

  const offset = (page - 1) * PAGE_SIZE

  const params = {
    offset,
    limit: PAGE_SIZE,
    status,
    contribution_type: type,
  }

  const { data, isPending, isFetching, isError, error, refetch } = useContributions(params)
  const approveMutation = useApproveContributionMutation()
  const rejectMutation = useRejectContributionMutation()

  const hasActiveFilters = status !== undefined || type !== undefined

  const clearFilters = () => {
    setStatus(undefined)
    setType(undefined)
    setPage(1)
  }

  const pages = data ? Math.max(1, Math.ceil(data.total / PAGE_SIZE)) : 1

  return (
    <div className="contributions-page">
      <header className="contributions-header">
        <div>
          <h2>مراجعة المساهمات</h2>
          <p className="muted">إدارة اقتراحات المستخدمين للأماكن: قبولها أو رفضها بعد المراجعة.</p>
        </div>
      </header>

      <div className="card contributions-filters">
        <label className="filter-field">
          <span className="filter-label">الحالة</span>
          <select
            value={status ?? ''}
            onChange={(event) => {
              setStatus(event.target.value === '' ? undefined : (event.target.value as ContributionStatus))
              setPage(1)
            }}
          >
            <option value="">الكل</option>
            <option value="PENDING">قيد الانتظار</option>
            <option value="APPROVED">معتمدة</option>
            <option value="REJECTED">مرفوضة</option>
            <option value="CANCELLED">ملغاة</option>
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">نوع المساهمة</span>
          <select
            value={type ?? ''}
            onChange={(event) => {
              setType(event.target.value === '' ? undefined : (event.target.value as ContributionType))
              setPage(1)
            }}
          >
            <option value="">الكل</option>
            <option value="CREATE_PLACE">إنشاء مكان</option>
            <option value="UPDATE_PLACE">تعديل مكان</option>
            <option value="ADD_IMAGE">إضافة صورة</option>
            <option value="UPDATE_INFORMATION">تحديث معلومات</option>
            <option value="VERIFY_PLACE">التحقق من مكان</option>
          </select>
        </label>
        {hasActiveFilters && (
          <button type="button" className="btn btn-ghost" onClick={clearFilters}>
            <RotateCcw size={16} /> مسح الفلاتر
          </button>
        )}
      </div>

      {approveMutation.isError && (
        <p className="error-note" role="alert">
          {userFacingError(approveMutation.error, 'تعذر إتمام الموافقة.')}
        </p>
      )}
      {rejectMutation.isError && (
        <p className="error-note" role="alert">
          {userFacingError(rejectMutation.error, 'تعذر إتمام الرفض.')}
        </p>
      )}

      <ContributionsResult
        isPending={isPending}
        isError={isError}
        error={error}
        data={
          data
            ? {
                items: data.items,
                page,
                pages,
                total: data.total,
              }
            : undefined
        }
        isFetching={isFetching}
        canApprove={canApprove}
        canReject={canReject}
        onApproveRequest={setPendingApprove}
        onRejectRequest={setPendingReject}
        onRetry={() => void refetch()}
        onPageChange={setPage}
      />

      {pendingApprove && (
        <ApproveModal
          contribution={pendingApprove}
          mutation={approveMutation}
          onClose={() => setPendingApprove(null)}
        />
      )}
      {pendingReject && (
        <RejectModal
          contribution={pendingReject}
          mutation={rejectMutation}
          onClose={() => setPendingReject(null)}
        />
      )}
    </div>
  )
}
function ContributionsResult({
  isPending,
  isError,
  error,
  data,
  isFetching,
  canApprove,
  canReject,
  onApproveRequest,
  onRejectRequest,
  onRetry,
  onPageChange,
}: {
  isPending: boolean
  isError: boolean
  error: unknown
  data?: { items: ContributionRead[]; page: number; pages: number; total: number }
  isFetching: boolean
  canApprove: boolean
  canReject: boolean
  onApproveRequest: (contribution: ContributionRead) => void
  onRejectRequest: (contribution: ContributionRead) => void
  onRetry: () => void
  onPageChange: (page: number) => void
}) {
  if (isPending) {
    return (
      <div className="card state-card" aria-busy="true">
        <p>جارٍ تحميل المساهمات…</p>
      </div>
    )
  }
  if (isError) {
    return (
      <div className="card state-card" role="alert">
        <ShieldAlert size={24} aria-hidden />
        <p>{userFacingError(error, 'تعذر تحميل المساهمات.')}</p>
        <button type="button" className="btn btn-primary" onClick={onRetry}>
          <RotateCcw size={16} /> إعادة المحاولة
        </button>
      </div>
    )
  }
  if (!data || data.items.length === 0) {
    return (
      <div className="card state-card">
        <ClipboardCheck size={24} aria-hidden />
        <p>لا توجد مساهمات مطابقة.</p>
      </div>
    )
  }
  return (
    <>
      <div className="card table-card">
        <div className="table-scroll">
          <table className="contributions-table">
            <thead>
              <tr>
                <th>المساهمة</th>
                <th>المستخدم</th>
                <th>المكان</th>
                <th>النوع</th>
                <th>الحالة</th>
                <th>النقاط</th>
                <th>التاريخ</th>
                <th>إجراء</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((contribution) => (
                <tr key={contribution.id}>
                  <td className="contribution-cell">
                    <span className="contribution-title">{contribution.title}</span>
                    {contribution.description && (
                      <p className="contribution-desc">{contribution.description}</p>
                    )}
                  </td>
                  <td className="mono cell-muted">{contribution.user_id}</td>
                  <td className="mono cell-muted">
                    {contribution.place_id ?? '—'}
                  </td>
                  <td>{TYPE_LABELS[contribution.type]}</td>
                  <td>{statusBadge(contribution.status)}</td>
                  <td>{contribution.points_awarded}</td>
                  <td className="cell-muted">{formatDate(contribution.created_at)}</td>
                  <td className="actions-cell">
                    {contribution.status === 'PENDING' && (
                      <>
                        {canApprove && (
                          <button
                            type="button"
                            className="btn btn-primary btn-sm"
                            disabled={isFetching}
                            onClick={() => onApproveRequest(contribution)}
                          >
                            <CheckCircle2 size={14} /> اعتماد
                          </button>
                        )}
                        {canReject && (
                          <button
                            type="button"
                            className="btn btn-danger btn-sm"
                            disabled={isFetching}
                            onClick={() => onRejectRequest(contribution)}
                          >
                            <XCircle size={14} /> رفض
                          </button>
                        )}
                      </>
                    )}
                    {contribution.status !== 'PENDING' && (
                      <span className="cell-muted">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <nav className="pagination" aria-label="تنقل الصفحات">
        <span className="cell-muted">
          صفحة {data.page} من {data.pages} · {data.total} مساهمة
          {isFetching ? ' · جارٍ التحديث…' : ''}
        </span>
        <div className="pagination-actions">
          <button
            type="button"
            className="btn btn-ghost"
            disabled={data.page <= 1 || isFetching}
            onClick={() => onPageChange(data.page - 1)}
          >
            السابق
          </button>
          <button
            type="button"
            className="btn btn-ghost"
            disabled={data.page >= data.pages || isFetching}
            onClick={() => onPageChange(data.page + 1)}
          >
            التالي
          </button>
        </div>
      </nav>
    </>
  )
}
/** Approve modal; the optional points field maps to the optional backend `points`. */
function ApproveModal({
  contribution,
  mutation,
  onClose,
}: {
  contribution: ContributionRead
  mutation: {
    isError: boolean
    isPending: boolean
    error: unknown
    mutate: (args: { id: string; payload: { points?: number | null } }, opts?: { onSuccess?: () => void }) => void
  }
  onClose: () => void
}) {
  const [points, setPoints] = useState('')

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h4>اعتماد المساهمة</h4>
        <p className="modal-summary">
          سيتم اعتماد «{contribution.title}» ومنح المستخدم النقاط. إذا تُرك الحقل فارغًا ستُستخدم النقاط الافتراضية.
        </p>
        {mutation.isError && (
          <p className="error-note" role="alert">
            {userFacingError(mutation.error, 'تعذر إتمام الموافقة.')}
          </p>
        )}
        <div className="modal-field">
          <label htmlFor="approve-points">النقاط الممنوحة (اختياري)</label>
          <input
            id="approve-points"
            type="number"
            min={0}
            value={points}
            placeholder="اتركها فارغة للافتراضي"
            onChange={(event) => setPoints(event.target.value)}
          />
        </div>
        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-primary"
            disabled={mutation.isPending}
            onClick={() =>
              mutation.mutate(
                {
                  id: contribution.id,
                  payload:
                    points === '' ? {} : { points: Number(points) },
                },
                { onSuccess: onClose },
              )
            }
          >
            {mutation.isPending ? 'جارٍ التنفيذ…' : 'تأكيد الاعتماد'}
          </button>
          <button type="button" className="btn btn-ghost" disabled={mutation.isPending} onClick={onClose}>
            إلغاء
          </button>
        </div>
      </div>
    </div>
  )
}

/** Reject modal; the rejection reason is required by the backend. */
function RejectModal({
  contribution,
  mutation,
  onClose,
}: {
  contribution: ContributionRead
  mutation: {
    isError: boolean
    isPending: boolean
    error: unknown
    mutate: (args: { id: string; payload: { rejection_reason: string } }, opts?: { onSuccess?: () => void }) => void
  }
  onClose: () => void
}) {
  const [reason, setReason] = useState('')
  const [validationError, setValidationError] = useState<string | null>(null)

  const confirm = () => {
    if (reason.trim() === '') {
      setValidationError('سبب الرفض مطلوب.')
      return
    }
    mutation.mutate(
      { id: contribution.id, payload: { rejection_reason: reason.trim() } },
      { onSuccess: onClose },
    )
  }

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h4>رفض المساهمة</h4>
        <p className="modal-summary">
          سيتم رفض «{contribution.title}» ولن تُطبق على النظام. سيظهر السبب للمستخدم.
        </p>
        {mutation.isError && (
          <p className="error-note" role="alert">
            {userFacingError(mutation.error, 'تعذر إتمام الرفض.')}
          </p>
        )}
        <div className="modal-field">
          <label htmlFor="reject-reason">سبب الرفض</label>
          <textarea
            id="reject-reason"
            className="reason-input"
            maxLength={2000}
            value={reason}
            placeholder="اذكر سبب الرفض بوضوح…"
            onChange={(event) => {
              setReason(event.target.value)
              setValidationError(null)
            }}
          />
        </div>
        {validationError && (
          <p className="error-note" role="alert">
            {validationError}
          </p>
        )}
        <div className="modal-actions">
          <button type="button" className="btn btn-danger" disabled={mutation.isPending} onClick={confirm}>
            {mutation.isPending ? 'جارٍ التنفيذ…' : 'تأكيد الرفض'}
          </button>
          <button type="button" className="btn btn-ghost" disabled={mutation.isPending} onClick={onClose}>
            إلغاء
          </button>
        </div>
      </div>
    </div>
  )
}