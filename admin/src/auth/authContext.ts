import { createContext } from 'react'
import type { AdminSession, AuthStatus } from '../types/auth'

export type AuthContextValue = {
  status: AuthStatus
  admin: AdminSession | null
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  hasPermission: (permission: string) => boolean
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined)
