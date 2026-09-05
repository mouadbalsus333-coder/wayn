import { useEffect, useState, type ReactNode } from 'react'
import { getAdminSession, webLogin, webLogout } from './authApi'
import { ApiError } from '../api/errors'
import { AuthContext, type AuthContextValue } from './authContext'
import type { AdminSession, AuthStatus } from '../types/auth'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>('loading')
  const [admin, setAdmin] = useState<AdminSession | null>(null)

  useEffect(() => {
    let active = true
    getAdminSession()
      .then((session) => {
        if (!active) return
        setAdmin(session)
        setStatus('authenticated')
      })
      .catch((error: unknown) => {
        if (!active) return
        if (error instanceof ApiError && error.status !== 401) {
          console.error(error)
        }
        setAdmin(null)
        setStatus('unauthenticated')
      })
    return () => {
      active = false
    }
  }, [])

  async function login(email: string, password: string) {
    await webLogin(email, password)
    const session = await getAdminSession()
    setAdmin(session)
    setStatus('authenticated')
  }

  async function logout() {
    try {
      await webLogout()
    } finally {
      setAdmin(null)
      setStatus('unauthenticated')
    }
  }

  const value: AuthContextValue = {
    status,
    admin,
    login,
    logout,
    hasPermission: (permission) => admin?.permissions.includes(permission) ?? false,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

