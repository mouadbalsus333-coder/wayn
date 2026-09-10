import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'

export function AdminLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)

  function openSidebar() {
    setSidebarOpen(true)
  }

  function closeSidebar() {
    setSidebarOpen(false)
  }

  return (
    <div className="admin-shell">
      <Sidebar open={sidebarOpen} onClose={closeSidebar} />
      <main className="admin-main">
        <Topbar onMenuClick={openSidebar} />
        <section className="admin-content">
          <Outlet />
        </section>
      </main>
    </div>
  )
}