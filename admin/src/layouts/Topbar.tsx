import { LogOut } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/useAuth'

export function Topbar() {
  const { admin, logout } = useAuth()
  const navigate = useNavigate()

  async function handleLogout() {
    await logout()
    navigate('/login', { replace: true })
  }

  return (
    <header className="topbar">
      <div>
        <p className="eyebrow">مساحة الإدارة</p>
        <h1>مرحبًا، {admin?.full_name || 'مدير WAYN'}</h1>
      </div>
      <button type="button" className="ghost-button" onClick={handleLogout}>
        <LogOut size={17} />
        تسجيل الخروج
      </button>
    </header>
  )
}
