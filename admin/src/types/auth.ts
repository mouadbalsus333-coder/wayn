export type AdminSession = {
  admin_id: number
  email: string
  full_name: string
  roles: string[]
  permissions: string[]
}

export type AuthStatus = 'loading' | 'authenticated' | 'unauthenticated'
