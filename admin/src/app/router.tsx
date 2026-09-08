import { Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { RequireAuth } from '../auth/RequireAuth'
import { RequireRole } from '../auth/RequireRole'
import { AdminUsersPage } from '../pages/AdminUsers/AdminUsersPage'
import { AdminUserDetailsPage } from '../pages/AdminUsers/AdminUserDetailsPage'
import { AdminUserCreatePage } from '../pages/AdminUsers/AdminUserCreatePage'
import { CommunityPage } from '../pages/Community/CommunityPage'
import { CommunityPostPage } from '../pages/Community/CommunityPostPage'
import { ContributionsPage } from '../pages/Contributions/ContributionsPage'
import { CategoriesPage } from '../pages/Categories/CategoriesPage'
import { PermissionsPage } from '../pages/Permissions/PermissionsPage'
import { StorePage } from '../pages/Store/StorePage'
import { WalletPage } from '../pages/Wallet/WalletPage'
import { RequirePermission } from '../auth/RequirePermission'
import { AdminLayout } from '../layouts/AdminLayout'
import { LoginPage } from '../pages/Login/LoginPage'
import { DashboardPage } from '../pages/Dashboard'
import { PlaceEditPage } from '../pages/Places/PlaceEditPage'
import { PlaceCreatePage } from '../pages/Places/PlaceCreatePage'
import { PlaceDetailsPage } from '../pages/Places/PlaceDetailsPage'
import { PlacesPage } from '../pages/Places/PlacesPage'
import { permissions } from '../permissions/permissionNames'
import { RegularUsersPage } from '../pages/RegularUsers/RegularUsersPage'
import { RegularUserDetailsPage } from '../pages/RegularUsers/RegularUserDetailsPage'
import { ReviewsPage } from '../pages/Reviews/ReviewsPage'

function ProtectedLayout() {
  return (
    <RequireAuth>
      <AdminLayout />
    </RequireAuth>
  )
}

export function AppRouter() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route element={<ProtectedLayout />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route
          path="/places"
          element={
            <RequirePermission permission={permissions.placesRead}>
              <PlacesPage />
            </RequirePermission>
          }
        />
        <Route
          path="/places/new"
          element={
            <RequirePermission permission={permissions.placesWrite}>
              <PlaceCreatePage />
            </RequirePermission>
          }
        />
        <Route
          path="/places/:id"
          element={
            <RequirePermission permission={permissions.placesRead}>
              <PlaceDetailsPage />
            </RequirePermission>
          }
        />
        <Route
          path="/places/:id/edit"
          element={
            <RequirePermission permission={permissions.placesWrite}>
              <PlaceEditPage />
            </RequirePermission>
          }
        />
        <Route
          path="/users"
          element={
            <RequireRole role="super_admin">
              <AdminUsersPage />
            </RequireRole>
          }
        />
        <Route
          path="/users/new"
          element={
            <RequireRole role="super_admin">
              <AdminUserCreatePage />
            </RequireRole>
          }
        />
        <Route
          path="/users/:id"
          element={
            <RequireRole role="super_admin">
              <AdminUserDetailsPage />
            </RequireRole>
          }
        />
        <Route
          path="/community"
          element={
            <RequirePermission permission={permissions.communityRead}>
              <CommunityPage />
            </RequirePermission>
          }
        />
        <Route
          path="/community/:id"
          element={
            <RequirePermission permission={permissions.communityRead}>
              <CommunityPostPage />
            </RequirePermission>
          }
        />
        <Route
          path="/contributions"
          element={
            <RequirePermission permission={permissions.contributionsRead}>
              <ContributionsPage />
            </RequirePermission>
          }
        />
        <Route
          path="/regular-users"
          element={
            <RequirePermission permission={permissions.usersRead}>
              <RegularUsersPage />
            </RequirePermission>
          }
        />
        <Route
          path="/regular-users/:id"
          element={
            <RequirePermission permission={permissions.usersRead}>
              <RegularUserDetailsPage />
            </RequirePermission>
          }
        />
        <Route
          path="/wallet"
          element={
            <RequirePermission permission={permissions.walletRead}>
              <WalletPage />
            </RequirePermission>
          }
        />
        <Route
          path="/categories"
          element={
            <RequirePermission permission={permissions.categoriesRead}>
              <CategoriesPage />
            </RequirePermission>
          }
        />
        <Route
          path="/store"
          element={
            <RequirePermission permission={permissions.storeRead}>
              <StorePage />
            </RequirePermission>
          }
        />
        <Route
          path="/permissions"
          element={
            <RequireRole role="super_admin">
              <PermissionsPage />
            </RequireRole>
          }
        />
        <Route
          path="/reviews"
          element={
            <RequirePermission permission={permissions.reviewsRead}>
              <ReviewsPage />
            </RequirePermission>
          }
        />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export function ProtectedOutlet() {
  return <Outlet />
}
