import { apiRequest } from './client'
import type {
  AppealAdminListItem,
  AppealAdminRead,
  AppealRead,
  AppealStatusUpdate,
  AppealsListParams,
  AppealsResponse,
  ModerationStats,
  PostActionUpdate,
  ReportAdminListItem,
  ReportAdminRead,
  ReportRead,
  ReportStatusUpdate,
  ReportsListParams,
  ReportsResponse,
} from '../types/moderation'

const base = '/api/v1/admin/moderation'

// ============================================================
// Stats
// ============================================================

export function getAppealStats() {
  return apiRequest<ModerationStats>(`${base}/appeals/stats`)
}

export function getReportStats() {
  return apiRequest<ModerationStats>(`${base}/reports/stats`)
}

// ============================================================
// Appeals — list + detail
// ============================================================

export function listAppeals(params: AppealsListParams) {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  if (params.search && params.search.trim() !== '') {
    searchParams.set('search', params.search.trim())
  }
  if (params.status) searchParams.set('status', params.status)
  if (params.type) searchParams.set('type', params.type)
  if (params.created_from) searchParams.set('created_from', params.created_from)
  if (params.created_to) searchParams.set('created_to', params.created_to)

  return apiRequest<AppealsResponse>(
    `${base}/appeals?${searchParams.toString()}`,
  )
}

export function getAppeal(appealId: string) {
  return apiRequest<AppealAdminRead>(
    `${base}/appeals/${encodeURIComponent(appealId)}`,
  )
}

// ============================================================
// Appeals — user-facing
// ============================================================

export function getUserAppeals() {
  return apiRequest<AppealRead[]>(`/api/v1/community/appeals/mine`)
}

export function getUserAppealForPost(postId: string) {
  return apiRequest<AppealRead | null>(
    `/api/v1/community/posts/${encodeURIComponent(postId)}/appeals/me`,
  )
}

export function submitAppeal(postId: string, payload: { type: string; reason: string }) {
  return apiRequest<AppealRead>(
    `/api/v1/community/posts/${encodeURIComponent(postId)}/appeals`,
    { method: 'POST', body: payload },
  )
}

// ============================================================
// Appeals — admin mutations
// ============================================================

export function updateAppealStatus(appealId: string, payload: AppealStatusUpdate) {
  return apiRequest<AppealAdminRead>(
    `${base}/appeals/${encodeURIComponent(appealId)}/status`,
    { method: 'PATCH', body: payload },
  )
}

export function applyAppealPostAction(appealId: string, payload: PostActionUpdate) {
  return apiRequest<AppealAdminRead>(
    `${base}/appeals/${encodeURIComponent(appealId)}/post-action`,
    { method: 'POST', body: payload },
  )
}

// ============================================================
// Reports — list + detail
// ============================================================

export function listReports(params: ReportsListParams) {
  const searchParams = new URLSearchParams()
  searchParams.set('page', String(params.page))
  searchParams.set('limit', String(params.limit))
  if (params.search && params.search.trim() !== '') {
    searchParams.set('search', params.search.trim())
  }
  if (params.status) searchParams.set('status', params.status)
  if (params.category) searchParams.set('category', params.category)
  if (params.created_from) searchParams.set('created_from', params.created_from)
  if (params.created_to) searchParams.set('created_to', params.created_to)

  return apiRequest<ReportsResponse>(
    `${base}/reports?${searchParams.toString()}`,
  )
}

export function getReport(reportId: string) {
  return apiRequest<ReportAdminRead>(
    `${base}/reports/${encodeURIComponent(reportId)}`,
  )
}

// ============================================================
// Reports — user-facing
// ============================================================

export function getUserReports() {
  return apiRequest<ReportRead[]>(`/api/v1/community/reports/mine`)
}

export function submitReport(postId: string, payload: { category: string; description: string }) {
  return apiRequest<ReportRead>(
        `/api/v1/community/posts/${encodeURIComponent(postId)}/reports`,
    { method: 'POST', body: payload },
  )
}

// ============================================================
// Reports — admin mutations
// ============================================================

export function updateReportStatus(reportId: string, payload: ReportStatusUpdate) {
  return apiRequest<ReportAdminRead>(
    `${base}/reports/${encodeURIComponent(reportId)}/status`,
    { method: 'PATCH', body: payload },
  )
}

export function applyReportPostAction(reportId: string, payload: PostActionUpdate) {
  return apiRequest<ReportAdminRead>(
    `${base}/reports/${encodeURIComponent(reportId)}/post-action`,
    { method: 'POST', body: payload },
  )
}
