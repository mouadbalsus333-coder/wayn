import { Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { RequireAuth } from '../auth/RequireAuth'
import { AdminLayout } from '../layouts/AdminLayout'
import { LoginPage } from '../pages/Login/LoginPage'
import { DashboardPlaceholder } from '../pages/DashboardPlaceholder'

function ProtectedLayout() {
  return (
    <RequireAuth>
      <AdminLayout />
    </RequireAuth>
  )
}

export function AppRouter() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<ProtectedLayout />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<DashboardPlaceholder />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export function ProtectedOutlet() {
  return <Outlet />
}
