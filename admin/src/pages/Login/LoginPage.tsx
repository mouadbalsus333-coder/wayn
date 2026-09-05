import { FormEvent, useState } from 'react'
import { ArrowLeft, LockKeyhole, Mail, ShieldCheck } from 'lucide-react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../../auth/useAuth'
import { userFacingError } from '../../api/errors'

export function LoginPage() {
  const { status, login } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [submitting, setSubmitting] = useState(false)

  if (status === 'authenticated') return <Navigate to="/dashboard" replace />

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    setSubmitting(true)
    try {
      await login(email.trim(), password)
      const from = (location.state as { from?: string } | null)?.from || '/dashboard'
      navigate(from, { replace: true })
    } catch (reason) {
      setError(userFacingError(reason, 'تعذر تسجيل الدخول. تحقق من بياناتك.'))
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="login-page">
      <div className="login-visual">
        <div className="visual-grid" />
        <div className="visual-copy">
          <span className="brand-mark large"><ShieldCheck size={28} /></span>
          <p className="eyebrow">WAYN / ADMIN</p>
          <h1>إدارة أوضح،<br />قرارات أسرع.</h1>
          <p>مساحة تشغيل مركزية لفريق WAYN، بصلاحيات واضحة وبيانات موثوقة من النظام.</p>
        </div>
        <div className="visual-rule" />
      </div>
      <section className="login-panel" aria-label="تسجيل دخول الإدارة">
        <div className="login-card">
          <div className="mobile-brand"><span className="brand-mark"><ShieldCheck size={20} /></span><strong>WAYN Admin</strong></div>
          <p className="eyebrow">دخول آمن</p>
          <h2>مرحبًا بعودتك</h2>
          <p className="muted">سجل الدخول للوصول إلى مساحة الإدارة.</p>
          <form onSubmit={handleSubmit} className="login-form">
            <label>
              البريد الإلكتروني
              <span className="input-wrap"><Mail size={17} /><input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="username" required /></span>
            </label>
            <label>
              كلمة المرور
              <span className="input-wrap"><LockKeyhole size={17} /><input type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required /></span>
            </label>
            {error && <div className="form-error" role="alert">{error}</div>}
            <button className="primary-button" type="submit" disabled={submitting}>
              {submitting ? 'جارٍ التحقق...' : 'دخول إلى لوحة الإدارة'}
              {!submitting && <ArrowLeft size={17} />}
            </button>
          </form>
          <p className="security-note"><ShieldCheck size={15} /> تتم إدارة الجلسة بأمان عبر الخادم</p>
        </div>
      </section>
    </main>
  )
}
