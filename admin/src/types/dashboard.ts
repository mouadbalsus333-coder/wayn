/**
 * Response of `GET /api/v1/admin/dashboard/summary`.
 *
 * Every metric is `number | null`. The backend returns `null` for a metric
 * the current admin is not allowed to read (permission-aware), so the UI
 * must never render a literal `null` — unavailable metrics are hidden.
 */
export type DashboardSummary = {
  total_users: number | null
  active_users: number | null
  total_places: number | null
  pending_places: number | null
  pending_contributions: number | null
  visible_community_posts: number | null
  visible_reviews: number | null
  wallet_recharge_operations: number | null
}