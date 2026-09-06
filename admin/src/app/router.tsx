import { Navigate, Outlet, Route, Routes } from 'react-router-dom'
import { RequireAuth } from '../auth/RequireAuth'
import { RequireRole } from '../auth/RequireRole'
import { AdminUsersPage } from '../pages/AdminUsers/AdminUsersPage'
import { AdminUserDetailsPage } from '../pages/AdminUsers/AdminUserDetailsPage'
import { CommunityPage } from '../pages/Community/CommunityPage'
import { CommunityPostPage } from '../pages/Community/CommunityPostPage'
import { RequirePermission } from '../auth/RequirePermission'
import { AdminLayout } from '../layouts/AdminLayout'
import { LoginPage } from '../pages/Login/LoginPage'
import { DashboardPage } from '../pages/Dashboard'
import { PlaceEditPage } from '../pages/Places/PlaceEditPage'
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
