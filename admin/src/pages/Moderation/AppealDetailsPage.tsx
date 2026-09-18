import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import {
  useAppeal,
  useAppealStatusMutation,
  useAppealPostActionMutation,
} from '../../hooks/useModeration'
import type { AppealStatus } from '../../types/moderation'
import {
  APPEAL_TYPE_LABELS,
  ActionsTrail,
  POST_ACTION_LABELS,
  PostPreviewCard,
  StatusBadge,
  formatDate,
} from './moderationShared'
import './moderation.css'

export function AppealDetailsPage() {
  const { id } = useParams<{ id: string }>()
  const { data: appeal, isPending, isError, error } = useAppeal(id ?? null)

  const statusMutation = useAppealStatusMutation()
  const postActionMutation = useAppealPostActionMutation()

  const [notes, setNotes] = useState('')
  const [postAction, setPostAction] = useState('LEAVE_AS_IS')
  const [actionNotes, setActionNotes] = useState('')
  const [confirmingAction, setConfirmingAction] = useState(false)

  if (isPending) {
    return <div className="moderation-page"><div className="card state-card">جارٍ تحميل الطعن…</div></div>
  }

  if (isError || !appeal) {
    return (
      <div className="moderation-page">
        <div className="card state-card">
          <p>تعذر تحميل الطعن.</p>
          <p className="error-note">{userFacingError(error)}</p>
          <Link className="btn btn-ghost" to="/moderation/appeals">العودة للقائمة</Link>
        </div>
      </div>
    )
  }

  const changeStatus = (target: AppealStatus) => {
    statusMutation.mutate(
      { appealId: appeal.id, payload: { status: target, admin_notes: notes.trim() || null } },
    )
  }

  return (
    <div className="moderation-page">
      <header className="moderation-header">
        <div>
          <Link to="/moderation/appeals" className="back-link">
            <ArrowRight size={16} aria-hidden /> العودة للطعون
          </Link>
          <h2>
            الطعن <span className="mono">{appeal.id.slice(0, 8)}</span>{' '}
            <StatusBadge status={appeal.status} />
          </h2>
        </div>
      </header>

      <div className="card appeal-info">
        <h3>معلومات الطعن</h3>
        <dl className="info-grid">
          <div><dt>تاريخ الإنشاء</dt><dd>{formatDate(appeal.created_at)}</dd></div>
          <div><dt>آخر تحديث</dt><dd>{formatDate(appeal.updated_at)}</dd></div>
          <div><dt>نوع الطعن</dt><dd>{APPEAL_TYPE_LABELS[appeal.type] ?? appeal.type}</dd></div>
          <div><dt>الطاعن</dt><dd>{appeal.complainant_name ?? '—'}{appeal.complainant_username ? ` (@${appeal.complainant_username})` : ''}</dd></div>
          <div><dt>صاحب المنشور</dt><dd>{appeal.post_owner_name ?? '—'}{appeal.post_owner_username ? ` (@${appeal.post_owner_username})` : ''}</dd></div>
          <div><dt>قرار المنشور الحالي</dt><dd>{POST_ACTION_LABELS[appeal.action_taken ?? 'NONE'] ?? '—'}</dd></div>
          {appeal.reviewed_by_email && (
            <div><dt>راجعه</dt><dd>{appeal.reviewed_by_email}</dd></div>
          )}
          {appeal.reviewed_at && (
            <div><dt>تاريخ المراجعة</dt><dd>{formatDate(appeal.reviewed_at)}</dd></div>
          )}
        </dl>
        <div className="reason-block">
          <strong>سبب الطعن</strong>
          <p className="post-body">{appeal.reason}</p>
        </div>
      </div>

      <PostPreviewCard post={appeal.post} />

      <ActionsTrail actions={appeal.actions} />

      <div className="card appeal-actions">
        <h3>إجراءات الحالة</h3>
        <p className="cell-muted">
          تغيير الحالة لا يحذف أو يخفي المنشور تلقائيًا؛ قرار المنشور يُتخذ بشكل منفصل أدناه.
          سيصل المستخدم إشعار بنتيجة المراجعة تلقائيًا.
        </p>
        <label className="filter-field">
          <span className="filter-label">ملاحظات إدارية (داخلية)</span>
          <textarea
            rows={3}
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder="مثال: تمت مراجعة التقييم ومقارنته بالمعلومات المتوفرة…"
          />
        </label>
        {statusMutation.isError && (
          <p className="error-note" role="alert">{userFacingError(statusMutation.error)}</p>
        )}
        <div className="action-buttons">
          {appeal.status === 'PENDING' && (
            <button
              type="button"
              className="btn btn-ghost"
              disabled={statusMutation.isPending}
              onClick={() => changeStatus('UNDER_REVIEW')}
            >
              بدء المراجعة
            </button>
          )}
          {appeal.status !== 'RESOLVED' && (
            <button
              type="button"
              className="btn btn-primary"
              disabled={statusMutation.isPending}
              onClick={() => changeStatus('RESOLVED')}
            >
              قبول الطعن (تمت المعالجة)
            </button>
          )}
          {(appeal.status === 'PENDING' || appeal.status === 'UNDER_REVIEW') && (
            <button
              type="button"
              className="btn btn-ghost"
              disabled={statusMutation.isPending}
              onClick={() => changeStatus('REJECTED')}
            >
              رفض الطعن
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
                      appealId: appeal.id,
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

