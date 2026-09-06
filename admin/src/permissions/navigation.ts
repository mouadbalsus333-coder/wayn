import { LayoutDashboard, MapPin, MessagesSquare, Star, Users, UserRound, type LucideIcon } from 'lucide-react'
import { permissions } from './permissionNames'

export type NavigationItem = {
  label: string
  path: string
  icon: LucideIcon
  permission?: string
  /** Route guarded by an admin *role* (e.g. super_admin) instead of a permission. */
  role?: string
}

export const navigationItems: NavigationItem[] = [
  { label: 'الرئيسية', path: '/dashboard', icon: LayoutDashboard },
  { label: 'الأماكن', path: '/places', icon: MapPin, permission: permissions.placesRead },
  { label: 'المستخدمون', path: '/users', icon: Users, role: 'super_admin' },
  { label: 'المستخدمون العاديون', path: '/regular-users', icon: UserRound, permission: permissions.usersRead },
  { label: 'المجتمع', path: '/community', icon: MessagesSquare, permission: permissions.communityRead },
  { label: 'المراجعات', path: '/reviews', icon: Star, permission: permissions.reviewsRead },
]
