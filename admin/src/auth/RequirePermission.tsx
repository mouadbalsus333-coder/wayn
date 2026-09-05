import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from './useAuth'

export function RequirePermission({ permission }: { permission: string }) {
  const { hasPermission } = useAuth()
  return hasPermission(permission) ? <Outlet /> : <Navigate to="/dashboard" replace />
}
