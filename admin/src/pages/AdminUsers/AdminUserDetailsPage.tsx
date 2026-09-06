import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { ArrowRight, BadgeCheck, Loader2, RefreshCw, ShieldAlert } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAdminUser } from '../../hooks/useAdminUsers'
import { useAdminUserStatusMutation } from '../../hooks/useAdminUserMutations'
import { useAuth } from '../../auth/useAuth'
import { AdminUserRoles } from './AdminUserRoles'
import { AdminUserPermissions } from './AdminUserPermissions'
import { ResolvedPermissions } from './ResolvedPermissions'
import './admin-users.css'
import '../Places/place-actions.css'

export function AdminUserDetailsPage() {
  const { id } = useParams()
  const userId = id ? Number.parseInt(id, 10) : null
  const { admin: currentAdmin } = useAuth()
  const { data: user, isPending, isError, error, refetch } = useAdminUser(userId)
  const statusMutation = useAdminUserStatusMutation()

  const [confirmAction, setConfirmAction] = useState<'deactivate' | 'activate' | null>(null)

  if (isPending) {
    return (
      <div className="users-page">
        <div className="state-panel">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل بيانات المستخدم…</p>
        </div>
      </div>
    )
  }

  if (isError || !user) {
    const notFound = error instanceof Error && /not found/i.test(error.message)
    return (
      <div className="users-page">
        <Link className="back-link" to="/users"><ArrowRight size={16} /> العودة إلى مستخدمي الإدارة</Link>
        <div className="state-panel state-panel-error">
          <p>{notFound ? 'مستخدم الإدارة غير موجود.' : userFacingError(error)}</p>
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
      <Link className="back-link" to="/users"><ArrowRight size={16} /> العودة إلى مستخدمي الإدارة</Link>

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
            {user.is_active ? (
              isSuperAdminTarget ? (
                <span className="super-admin-note">
                  <ShieldAlert size={16} />
                  Super Admin لا يمكن تعطيله (محمي في الـ Backend).
                </span>
              ) : (
                <button
                  type="button"
                  className="danger-button"
                  onClick={() => setConfirmAction('deactivate')}
                  disabled={statusMutation.isPending}
                >
                  <ShieldAlert size={16} />
                  تعطيل الحساب
                </button>
              )
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
          </div>
          {isSelf && (
            <p className="self-note">
              هذا حسابك الخاص؛ تغيير الحالة سيُنهي جلستك الحالية فورًا (token_version).
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
            <h3>{confirmAction === 'deactivate' ? 'تأكيد تعطيل الحساب' : 'تأكيد تنشيط الحساب'}</h3>
            <p>
              {confirmAction === 'deactivate'
                ? 'سيتم تعطيل الحساب وإبطال جلساته الحالية فورًا. هل أنت متأكد؟'
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
                className={confirmAction === 'deactivate' ? 'danger-button' : 'primary-button'}
                disabled={statusMutation.isPending}
                onClick={() => {
                  if (userId === null) return
                  statusMutation.mutate(
                    { id: userId, active: confirmAction === 'activate' },
                    { onSuccess: () => setConfirmAction(null) },
                  )
                }}
              >
                {statusMutation.isPending && <Loader2 className="spin" size={15} />}
                {confirmAction === 'deactivate' ? 'تعطيل' : 'تنشيط'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
