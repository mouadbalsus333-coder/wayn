import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import {
  useReport,
  useReportStatusMutation,
  useReportPostActionMutation,
} from '../../hooks/useModeration'
import type { ReportStatus } from '../../types/moderation'
import {
  ActionsTrail,
  POST_ACTION_LABELS,
  PostPreviewCard,
  REPORT_CATEGORY_LABELS,
  StatusBadge,
  formatDate,
} from './moderationShared'
import './moderation.css'

export function ReportDetailsPage() {
  const { id } = useParams<{ id: string }>()
  const { data: report, isPending, isError, error } = useReport(id ?? null)

  const statusMutation = useReportStatusMutation()
  const postActionMutation = useReportPostActionMutation()

  const [notes, setNotes] = useState('')
  const [postAction, setPostAction] = useState('LEAVE_AS_IS')
  const [actionNotes, setActionNotes] = useState('')
  const [confirmingAction, setConfirmingAction] = useState(false)

  if (isPending) {
    return <div className="moderation-page"><div className="card state-card">جارٍ تحميل البلاغ…</div></div>
  }

  if (isError || !report) {
    return (
      <div className="moderation-page">
        <div className="card state-card">
          <p>تعذر تحميل البلاغ.</p>
          <p className="error-note">{userFacingError(error)}</p>
          <Link className="btn btn-ghost" to="/moderation/reports">العودة للقائمة</Link>
        </div>
      </div>
    )
  }

  const changeStatus = (target: ReportStatus) => {
    statusMutation.mutate(
      { reportId: report.id, payload: { status: target, admin_notes: notes.trim() || null } },
    )
  }

  return (
    <div className="moderation-page">
      <header className="moderation-header">
        <div>
          <Link to="/moderation/reports" className="back-link">
            <ArrowRight size={16} aria-hidden /> العودة للبلاغات
          </Link>
          <h2>
            البلاغ <span className="mono">{report.id.slice(0, 8)}</span>{' '}
            <StatusBadge status={report.status} />
          </h2>
        </div>
      </header>

      <div className="card appeal-info">
        <h3>معلومات البلاغ</h3>
        <dl className="info-grid">
          <div><dt>تاريخ البلاغ</dt><dd>{formatDate(report.created_at)}</dd></div>
          <div><dt>آخر تحديث</dt><dd>{formatDate(report.updated_at)}</dd></div>
          <div><dt>التصنيف</dt><dd>{REPORT_CATEGORY_LABELS[report.category] ?? report.category}</dd></div>
          <div><dt>المُبلِّغ</dt><dd>{report.reporter_name ?? '—'}{report.reporter_username ? ` (@${report.reporter_username})` : ''}</dd></div>
          <div><dt>صاحب المنشور</dt><dd>{report.post_owner_name ?? '—'}{report.post_owner_username ? ` (@${report.post_owner_username})` : ''}</dd></div>
          <div><dt>الإجراء الحالي</dt><dd>{POST_ACTION_LABELS[report.action_taken ?? 'NONE'] ?? '—'}</dd></div>
          {report.reviewed_by_email && (
            <div><dt>عالجه</dt><dd>{report.reviewed_by_email}</dd></div>
          )}
          {report.reviewed_at && (
            <div><dt>تاريخ المعالجة</dt><dd>{formatDate(report.reviewed_at)}</dd></div>
          )}
        </dl>
        <div className="reason-block">
          <strong>نص البلاغ</strong>
          <p className="post-body">{report.description}</p>
        </div>
        {report.admin_notes && (
          <div className="reason-block admin-notes-block">
            <strong>ملاحظات إدارية</strong>
            <p className="post-body">{report.admin_notes}</p>
          </div>
        )}
      </div>

      <PostPreviewCard post={report.post} />

      <ActionsTrail actions={report.actions} />

      <div className="card appeal-actions">
        <h3>إجراءات الحالة</h3>
        <p className="cell-muted">
          تغيير الحالة لا يحذف أو يخفي المنشور تلقائيًا؛ قرار المنشور يُتخذ بشكل منفصل أدناه.
          سيصل المُبلِّغ إشعار بنتيجة المعالجة تلقائيًا.
        </p>
        <label className="filter-field">
          <span className="filter-label">ملاحظات إدارية (داخلية)</span>
          <textarea
            rows={3}
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder="مثال: تمت مراجعة البلاغ واتخاذ الإجراء المناسب…"
          />
        </label>
        {statusMutation.isError && (
          <p className="error-note" role="alert">{userFacingError(statusMutation.error)}</p>
        )}
        <div className="action-buttons">
          {report.status === 'PENDING' && (
            <button
              type="button"
              className="btn btn-ghost"
              disabled={statusMutation.isPending}
              onClick={() => changeStatus('UNDER_REVIEW')}
            >
              بدء المراجعة
            </button>
          )}
          {report.status !== 'RESOLVED' && (
            <button
              type="button"
              className="btn btn-primary"
              disabled={statusMutation.isPending}
              onClick={() => changeStatus('RESOLVED')}
            >
              تمت المعالجة
            </button>
          )}
          {report.status !== 'REJECTED' && (
            <button
              type="button"
              className="btn btn-ghost"
              disabled={statusMutation.isPending}
              onClick={() => changeStatus('REJECTED')}
            >
              رفض البلاغ
            </button>
          )}
        </div>
      </div>

      <div className="card appeal-actions">
        <h3>إجراء على المنشور</h3>
        <div className="filter-field">
          <span className="filter-label">القرار</span>
          <select value={postAction} onChange={(event) => setPostAction(event.target.value)}>
            <option value="LEAVE_AS_IS">ترك المنشور كما هو</option>
            <option value="HIDE_POST">إخفاء المنشور</option>
            <option value="DELETE_POST">حذف المنشور</option>
          </select>
        </div>
        <label className="filter-field">
          <span className="filter-label">ملاحظات القرار</span>
          <textarea
            rows={2}
            value={actionNotes}
            onChange={(event) => setActionNotes(event.target.value)}
          />
        </label>
        {postActionMutation.isError && (
          <p className="error-note" role="alert">{userFacingError(postActionMutation.error)}</p>
        )}
        <div className="action-buttons">
          <button
            type="button"
            className="btn btn-primary"
            disabled={postActionMutation.isPending}
            onClick={() => setConfirmingAction(true)}
          >
            تطبيق القرار
          </button>
        </div>
      </div>

      {confirmingAction && (
        <div className="modal-overlay" role="dialog" aria-modal="true">
          <div className="modal-card">
            <h4>تأكيد القرار</h4>
            <p className="modal-summary">
              {postAction === 'DELETE_POST'
                ? 'سيتم حذف المنشور (حذف ناعم ينتقل لقائمة المحذوفات عند صاحبه).'
                : postAction === 'HIDE_POST'
                  ? 'سيتم إخفاء المنشور عن العرض العام.'
                  : 'سيتم تسجيل أن المنشور بقي كما هو.'}
            </p>
            <div className="modal-actions">
              <button
                type="button"
                className="btn btn-primary"
                disabled={postActionMutation.isPending}
                onClick={() =>
                  postActionMutation.mutate(
                    {
                      reportId: report.id,
                      payload: { action: postAction as 'DELETE_POST' | 'HIDE_POST' | 'LEAVE_AS_IS', notes: actionNotes.trim() || null },
                    },
                    { onSuccess: () => setConfirmingAction(false) },
                  )
                }
              >
                {postActionMutation.isPending ? 'جارٍ التنفيذ…' : 'تأكيد'}
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                disabled={postActionMutation.isPending}
                onClick={() => setConfirmingAction(false)}
              >
                إلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
