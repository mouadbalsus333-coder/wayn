import { LogOut, Menu, Moon, Sun } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/useAuth'

type TopbarProps = {
onMenuClick: () => void
}

const THEME_KEY = 'wayn-admin-theme'

export function Topbar({ onMenuClick }: TopbarProps) {
const { admin, logout } = useAuth()
const navigate = useNavigate()

const [darkMode, setDarkMode] = useState(
() => localStorage.getItem(THEME_KEY) === 'dark',
)

useEffect(() => {
const root = document.documentElement

if (darkMode) {
  root.setAttribute('data-theme', 'dark')
  localStorage.setItem(THEME_KEY, 'dark')
} else {
  root.removeAttribute('data-theme')
  localStorage.setItem(THEME_KEY, 'light')
}

}, [darkMode])

async function handleLogout() {
await logout()
navigate('/login', { replace: true })
}

function toggleTheme() {
setDarkMode((current) => !current)
}

return ( <header className="topbar"> <div className="topbar-leading"> <button
       type="button"
       className="menu-button"
       onClick={onMenuClick}
       aria-label="فتح القائمة"
       title="فتح القائمة"
     > <Menu size={21} /> </button>

    <div>
      <p className="eyebrow">مساحة الإدارة</p>
      <h1>مرحبًا، {admin?.full_name || 'مدير WAYN'}</h1>
    </div>
  </div>

  <div className="topbar-actions">
    <button
      type="button"
      className="theme-button"
      onClick={toggleTheme}
      aria-label={darkMode ? 'تفعيل الوضع الفاتح' : 'تفعيل الوضع الداكن'}
      title={darkMode ? 'الوضع الفاتح' : 'الوضع الداكن'}
    >
      {darkMode ? <Sun size={18} /> : <Moon size={18} />}
    </button>

    <button type="button" className="ghost-button" onClick={handleLogout}>
      <LogOut size={17} />
      تسجيل الخروج
    </button>
  </div>
</header>

)
}
