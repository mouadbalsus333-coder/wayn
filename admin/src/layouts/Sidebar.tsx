import { NavLink } from 'react-router-dom'
import { ShieldCheck } from 'lucide-react'
import { navigationItems } from '../permissions/navigation'
import { useAuth } from '../auth/useAuth'

export function Sidebar() {
  const { hasPermission, admin } = useAuth()
  const visibleItems = navigationItems.filter((item) => {
    if (item.permission && !hasPermission(item.permission)) return false
    if (item.role && !admin?.roles.includes(item.role)) return false
    return true
  })

  return (
    <aside className="sidebar">
      <div className="brand-lockup">
        <span className="brand-mark"><ShieldCheck size={20} /></span>
        <span>
          <strong>WAYN</strong>
          <small>لوحة الإدارة</small>
        </span>
      </div>
      <nav aria-label="التنقل الرئيسي" className="sidebar-nav">
        {visibleItems.map((item) => {
          const Icon = item.icon
          return (
            <NavLink key={`${item.path}-${item.label}`} to={item.path} className="nav-item">
              <Icon size={18} />
              <span>{item.label}</span>
            </NavLink>
          )
        })}
      </nav>
      <div className="sidebar-footnote">بيئة إدارة آمنة</div>
    </aside>
  )
}
