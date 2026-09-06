import { Navigate, Outlet } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useAuth } from './useAuth'

/**
 * Route guard based on an admin *role* (e.g. `super_admin`).
 * Mirrors the backend `require_role(...)` dependency: some admin
 * endpoints are protected by role instead of a permission.
 */
export function RequireRole({ role, children }: { role: string; children?: ReactNode }) {
  const { admin } = useAuth()
  if (!admin?.roles.includes(role)) return <Navigate to="/dashboard" replace />
  return children ? <>{children}</> : <Outlet />
}
