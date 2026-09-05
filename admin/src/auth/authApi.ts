import { apiRequest } from '../api/client'
import type { AdminSession } from '../types/auth'

export function webLogin(email: string, password: string) {
  return apiRequest<AdminSession>('/api/v1/admin/auth/web-login', {
    method: 'POST',
    body: { email, password },
  })
}

export function getAdminSession() {
  return apiRequest<AdminSession>('/api/v1/admin/auth/me')
}

export function webLogout() {
  return apiRequest<void>('/api/v1/admin/auth/logout', { method: 'POST' })
}
