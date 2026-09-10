import { X, ShieldCheck } from 'lucide-react'
import { NavLink } from 'react-router-dom'
import { navigationItems } from '../permissions/navigation'
import { useAuth } from '../auth/useAuth'

type SidebarProps = {
  open: boolean
  onClose: () => void
}

export function Sidebar({ open, onClose }: SidebarProps) {
  const { hasPermission, admin } = useAuth()

  const visibleItems = navigationItems.filter((item) => {
    if (item.permission && !hasPermission(item.permission)) return false
    if (item.role && !admin?.roles.includes(item.role)) return false
    return true
  })

  return (
    <>
      <div
        className={`sidebar-overlay${open ? ' is-open' : ''}`}
        onClick={onClose}
        aria-hidden="true"
      />

      <aside className={`sidebar${open ? ' is-open' : ''}`}>
        <div className="sidebar-header">
          <div className="brand-lockup">
            <span className="brand-mark">
              <ShieldCheck size={20} />
            </span>

            <span>
              <strong>WAYN</strong>
              <small>ظ„ظˆطط© ط§ظ„ط¥ط¯ط§طط±ط©</small>
            </span>
          </div>

          <button
            type="button"
            className="sidebar-close"
            onClick={onClose}
            aria-label="إغلاق القائمة"
          >
            <X size={20} />
          </button>
        </div>

        <nav
          aria-label="ط§ظ„طھظ†ظ‚ظ„ ط§ظ„ط±ط¦ظٹط³ظٹ"
          className="sidebar-nav"
        >
          {visibleItems.map((item) => {
            const Icon = item.icon

            return (
              <NavLink
                key={`${item.path}-${item.label}`}
                to={item.path}
                className="nav-item"
                onClick={onClose}
              >
                <Icon size={18} />
                <span>{item.label}</span>
              </NavLink>
            )
          })}
        </nav>

        <div className="sidebar-footnote">
          ط¨ظٹط¦ط© ط¥ط¯ط§طط±ط© ط¢ظ…ظ†ط©
        </div>
      </aside>
    </>
  )
}