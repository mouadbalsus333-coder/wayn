import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ArrowRight, BadgeCheck, Loader2, Pencil, RefreshCw, ShieldAlert, Trash2 } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAdminUser } from '../../hooks/useAdminUsers'
import { useAdminUserStatusMutation } from '../../hooks/useAdminUserMutations'
import { useDeleteAdminUserMutation, useUpdateAdminUserMutation } from '../../hooks/useAdminUserCrudMutations'
import { useAuth } from '../../auth/useAuth'
import { AdminUserRoles } from './AdminUserRoles'
import { AdminUserPermissions } from './AdminUserPermissions'
import { ResolvedPermissions } from './ResolvedPermissions'
import './admin-users.css'
import '../Places/place-actions.css'

export function AdminUserDetailsPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const userId = id ? Number.parseInt(id, 10) : null
  const { admin: currentAdmin } = useAuth()
  const { data: user, isPending, isError, error, refetch } = useAdminUser(userId)
  const statusMutation = useAdminUserStatusMutation()
  const updateMutation = useUpdateAdminUserMutation()
  const deleteMutation = useDeleteAdminUserMutation()

  const [confirmAction, setConfirmAction] = useState<'deactivate' | 'activate' | 'delete' | null>(null)
  const [editOpen, setEditOpen] = useState(false)
  const [editFullName, setEditFullName] = useState('')
  const [editPassword, setEditPassword] = useState('')
  const [editFieldErrors, setEditFieldErrors] = useState<Record<string, string>>({})

  if (isPending) {
    return (
      <div className="users-page">
        <div className="state-panel">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل بيانات المشرف…</p>
        </div>
      </div>
    )
  }

  if (isError || !user) {
    const notFound = error instanceof Error && /not found/i.test(error.message)
    return (
      <div className="users-page">
        <Link className="back-link" to="/users"><ArrowRight size={16} /> العودة إلى المشرفين</Link>
        <div className="state-panel state-panel-error">
          <p>{notFound ? 'المشرف غير موجود.' : userFacingError(error)}</p>
          {!notFound && (
            <button type="button" className="ghost-button" onClick={() => refetch()}>
              <RefreshCw size={16} />
              إعادة المحاولة
            </button>
          )}
        </div>
      </div>
    )
  }

  const isSuperAdminTarget = user.roles.includes('super_admin')
  const isSelf = currentAdmin?.admin_id === user.id
  const mutationError = statusMutation.isError ? userFacingError(statusMutation.error) : null

  return (
    <div className="users-page place-actions-page">
      <Link className="back-link" to="/users"><ArrowRight size={16} /> العودة إلى المشرفين</Link>

      <div className="place-hero-card">
        <span className="user-avatar user-avatar-lg" aria-hidden="true">
          {user.full_name.trim().charAt(0) || '؟'}
        </span>
        <div className="place-hero-main">
          <h2>{user.full_name}</h2>
          <p className="muted" dir="ltr">{user.email}</p>
          <div className="place-hero-meta">
            {user.roles.map((name) => (
              <span key={name} className="service-chip">{name}</span>
            ))}
            {user.is_active ? (
              <span className="badge badge-active">نشط</span>
            ) : (
              <span className="badge badge-inactive">غير نشط</span>
            )}
          </div>
          <div className="place-hero-actions">
            <button
              type="button"
              className="ghost-button"
              onClick={() => {
                setEditFullName(user.full_name)
                setEditPassword('')
                setEditFieldErrors({})
                setEditOpen(true)
              }}
              disabled={updateMutation.isPending}
            >
              <Pencil size={16} /> تعديل البيانات
            </button>
            {user.is_active ? (
              <button
                type="button"
                className="danger-button"
                onClick={() => setConfirmAction('deactivate')}
                disabled={statusMutation.isPending}
              >
                <ShieldAlert size={16} />
                تعطيل الحساب
              </button>
            ) : (
              <button
                type="button"
                className="primary-button"
                onClick={() => setConfirmAction('activate')}
                disabled={statusMutation.isPending}
              >
                <BadgeCheck size={16} />
                تنشيط الحساب
              </button>
            )}
            <button
              type="button"
              className="danger-button"
              onClick={() => setConfirmAction('delete')}
              disabled={deleteMutation.isPending}
            >
              <Trash2 size={16} /> حذف الحساب
            </button>
          </div>
          {isSelf && (
            <p className="self-note">
              هذا حسابك الخاص؛ تغيير الحالة سيُنهي جلستك الحالية فورًا (token_version).
            </p>
          )}
          {isSuperAdminTarget && (
            <p className="super-admin-note">
              <ShieldAlert size={16} />
              آخر مشرف رئيسي نشط محمي في الـ Backend ولا يمكن تعطيله أو إزالة دوره.
            </p>
          )}
          {mutationError && <p className="mutation-error">{mutationError}</p>}
        </div>
      </div>

      <AdminUserRoles userId={user.id} />
      <AdminUserPermissions userId={user.id} />
      <ResolvedPermissions userId={user.id} />

      {confirmAction && (
        <div className="modal-backdrop" role="presentation">
          <div className="modal" role="dialog" aria-modal="true">
            <h3>
              {confirmAction === 'deactivate'
                ? 'تأكيد تعطيل الحساب'
                : confirmAction === 'delete'
                  ? 'تأكيد حذف الحساب'
                  : 'تأكيد تنشيط الحساب'}
            </h3>
            <p>
              {confirmAction === 'deactivate'
                ? 'سيتم تعطيل الحساب وإبطال جلساته الحالية فورًا. هل أنت متأكد؟'
                : confirmAction === 'delete'
                  ? 'سيتم حذف مستخدم الإدارة نهائيًا. إذا منع الـ Backend العملية (مثل حذف Super Admin) سيظهر خطؤه هنا. هل أنت متأكد؟'
                  : 'سيتم تنشيط الحساب ويمكن لصاحبه تسجيل الدخول مجددًا. هل أنت متأكد؟'}
            </p>
            <div className="modal-actions">
              <button
                type="button"
                className="ghost-button"
                onClick={() => setConfirmAction(null)}
                disabled={statusMutation.isPending}
              >
                إلغاء
              </button>
              <button
                type="button"
                className={confirmAction === 'activate' ? 'primary-button' : 'danger-button'}
                disabled={statusMutation.isPending}
                onClick={() => {
                  if (userId === null) return
                  if (confirmAction === 'delete') {
                    deleteMutation.mutate(userId, {
                      onSuccess: () => navigate('/users', { replace: true }),
                    })
                    return
                  }
                  statusMutation.mutate(
                    { id: userId, active: confirmAction === 'activate' },
                    { onSuccess: () => setConfirmAction(null) },
                  )
                }}
              >
                {(statusMutation.isPending || deleteMutation.isPending) && <Loader2 className="spin" size={15} />}
                {confirmAction === 'deactivate' ? 'تعطيل' : confirmAction === 'delete' ? 'حذف' : 'تنشيط'}
              </button>
            </div>
          </div>
        </div>
      )}

      {editOpen && user && (
        <div className="modal-backdrop" role="presentation">
          <div className="modal" role="dialog" aria-modal="true">
            <h3>تعديل بيانات المستخدم</h3>
            {updateMutation.isError && (
              <div className="mutation-error" role="alert">{userFacingError(updateMutation.error)}</div>
            )}
            <div className="form-grid">
              <div className="form-field">
                <label htmlFor="au-edit-name">الاسم الكامل</label>
                <input id="au-edit-name" value={editFullName} onChange={(e) => setEditFullName(e.target.value)} />
                {editFieldErrors.fullName && <span className="field-error">{editFieldErrors.fullName}</span>}
              </div>
              <div className="form-field">
                <label htmlFor="au-edit-password">كلمة مرور جديدة (اختياري)</label>
                <input
                  id="au-edit-password"
                  dir="ltr"
                  type="password"
                  placeholder="اتركها فارغة للإبقاء على الحالية"
                  value={editPassword}
                  onChange={(e) => setEditPassword(e.target.value)}
                />
                {editFieldErrors.password && <span className="field-error">{editFieldErrors.password}</span>}
              </div>
            </div>
            <div className="modal-actions">
              <button type="button" className="ghost-button" disabled={updateMutation.isPending} onClick={() => setEditOpen(false)}>
                إلغاء
              </button>
              <button
                type="button"
                className="primary-button"
                disabled={updateMutation.isPending}
                onClick={() => {
                  const errors: Record<string, string> = {}
                  if (!editFullName.trim()) errors.fullName = 'الاسم الكامل مطلوب'
                  if (editPassword.length > 0 && editPassword.length < 8) errors.password = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
                  setEditFieldErrors(errors)
                  if (Object.keys(errors).length > 0) return

                  const payload: { full_name: string; password?: string } = { full_name: editFullName.trim() }
                  if (editPassword.length > 0) payload.password = editPassword
                  updateMutation.mutate(
                    { id: user.id, payload },
                    { onSuccess: () => setEditOpen(false) },
                  )
                }}
              >
                {updateMutation.isPending ? <Loader2 className="spin" size={15} /> : null}
                {updateMutation.isPending ? 'جارٍ الحفظ…' : 'حفظ'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
