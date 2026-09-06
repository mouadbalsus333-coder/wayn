import { Navigate, Outlet } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from './useAuth'

export function RequirePermission({ permission, children }: { permission: string; children?: ReactNode }) {
  const { hasPermission } = useAuth()
  if (!hasPermission(permission)) return <Navigate to="/dashboard" replace />
  return children ? <>{children}</> : <Outlet />
}
