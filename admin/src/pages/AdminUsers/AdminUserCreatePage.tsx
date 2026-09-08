import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { ArrowRight, Loader2, UserPlus } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useCreateAdminUserMutation } from '../../hooks/useAdminUserCrudMutations'
import type { AdminUserCreatePayload } from '../../types/adminUser'
import './admin-users.css'
import '../Places/places.css'
import '../Places/place-actions.css'

/**
 * Create Admin User (`POST /api/v1/admin/users`) — `super_admin` only
 * (route guarded by RequireRole; the backend enforces it too).
 *
 * NOTE: the backend `AdminUserCreate` also accepts optional `role_ids` /
 * `permission_ids`, but there is no `GET /admin/roles` endpoint to list the
 * available roles, so the create form only sets the core fields. Roles and
 * direct permissions can be managed afterwards on the details page.
 */
export function AdminUserCreatePage() {
  const navigate = useNavigate()
  const createMutation = useCreateAdminUserMutation()

  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const submit = () => {
    const errors: Record<string, string> = {}
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) errors.email = 'بريد إلكتروني غير صالح'
    if (password.length < 8) errors.password = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
    if (!fullName.trim()) errors.fullName = 'الاسم الكامل مطلوب'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const payload: AdminUserCreatePayload = {
      email: email.trim(),
      password,
      full_name: fullName.trim(),
      is_active: isActive,
    }
    createMutation.mutate(payload, {
      onSuccess: (created) => navigate(`/users/${created.id}`, { replace: true }),
    })
  }

  return (
    <div className="users-page place-actions-page">
      <Link className="back-link" to="/users">
        <ArrowRight size={16} /> العودة إلى مستخدمي الإدارة
      </Link>

      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة النظام</p>
          <h2>إضافة مستخدم إدارة</h2>
          <p className="muted">
            يمكنك تعيين الأدوار والصلاحيات مباشرة بعد الإنشاء من صفحة التفاصيل.
          </p>
        </div>
      </header>

      {createMutation.isError && (
        <div className="mutation-error" role="alert">
          {userFacingError(createMutation.error, 'تعذر إنشاء مستخدم الإدارة.')}
        </div>
      )}

      <div className="card form-card">
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="au-email">البريد الإلكتروني *</label>
            <input id="au-email" dir="ltr" type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
            {fieldErrors.email && <span className="field-error">{fieldErrors.email}</span>}
          </div>
          <div className="form-field">
            <label htmlFor="au-name">الاسم الكامل *</label>
            <input id="au-name" value={fullName} onChange={(e) => setFullName(e.target.value)} />
            {fieldErrors.fullName && <span className="field-error">{fieldErrors.fullName}</span>}
          </div>
          <div className="form-field">
            <label htmlFor="au-password">كلمة المرور *</label>
            <input id="au-password" dir="ltr" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
            {fieldErrors.password && <span className="field-error">{fieldErrors.password}</span>}
          </div>
          <div className="form-field">
            <label className="form-toggle">
              <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
              الحساب نشط
            </label>
          </div>
        </div>

        <div className="modal-actions">
          <Link className="ghost-button" to="/users">إلغاء</Link>
          <button type="button" className="primary-button" disabled={createMutation.isPending} onClick={submit}>
            {createMutation.isPending ? <Loader2 className="spin" size={16} /> : <UserPlus size={16} />}
            {createMutation.isPending ? 'جارٍ الإنشاء…' : 'إنشاء المستخدم'}
          </button>
        </div>
      </div>
    </div>
  )
}
