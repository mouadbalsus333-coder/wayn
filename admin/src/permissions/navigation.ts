import { LayoutDashboard, type LucideIcon } from 'lucide-react'
import { permissions } from './permissionNames'

export type NavigationItem = {
  label: string
  path: string
  icon: LucideIcon
  permission?: string
}

export const navigationItems: NavigationItem[] = [
  { label: 'الرئيسية', path: '/dashboard', icon: LayoutDashboard },
  { label: 'المستخدم الحالي', path: '/dashboard', icon: LayoutDashboard, permission: permissions.usersRead },
]
