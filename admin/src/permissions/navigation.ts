import { LayoutDashboard, MapPin, MessagesSquare, Star, Users, UserRound, ClipboardCheck, Wallet, Tags, Store, Megaphone, ShieldCheck, type LucideIcon } from 'lucide-react'
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
  { label: 'المشرفين', path: '/users', icon: Users, role: 'super_admin' },
  { label: 'المستخدمين', path: '/regular-users', icon: UserRound, permission: permissions.usersRead },
  { label: 'المجتمع', path: '/community', icon: MessagesSquare, permission: permissions.communityRead },
  { label: 'المساهمات', path: '/contributions', icon: ClipboardCheck, permission: permissions.contributionsRead },
  { label: 'المراجعات', path: '/reviews', icon: Star, permission: permissions.reviewsRead },
  { label: 'المحفظة', path: '/wallet', icon: Wallet, permission: permissions.walletRead },
  { label: 'الفئات', path: '/categories', icon: Tags, permission: permissions.categoriesRead },
  { label: 'المتجر', path: '/store', icon: Store, permission: permissions.storeRead },
  { label: 'إعلانات المتجر', path: '/store-ads', icon: Megaphone, permission: permissions.storeRead },
  { label: 'الصلاحيات', path: '/permissions', icon: ShieldCheck, role: 'super_admin' },
]
