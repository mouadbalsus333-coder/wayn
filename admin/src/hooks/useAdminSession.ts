import { useAuth } from '../auth/useAuth'

export function useAdminSession() {
  return useAuth()
}
