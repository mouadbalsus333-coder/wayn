import { useQuery, keepPreviousData, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  getAppeal,
  getAppealStats,
  getReport,
  getReportStats,
  listAppeals,
  listReports,
  submitAppeal,
  submitReport,
  updateAppealStatus,
  updateReportStatus,
  applyAppealPostAction,
  applyReportPostAction,
} from '../api/moderation'
import type {
  AppealAdminRead,
  AppealCreate,
  AppealsListParams,
  AppealsResponse,
  ModerationStats,
  PostActionUpdate,
  ReportAdminRead,
  ReportCreate,
  ReportsListParams,
  ReportsResponse,
  ReportStatusUpdate,
  AppealStatusUpdate,
} from '../types/moderation'

// ============================================================
// Appeals — list + detail
// ============================================================

export function useAppeals(params: AppealsListParams) {
  return useQuery({
    queryKey: ['admin', 'appeals', 'list', params],
    queryFn: () => listAppeals(params),
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  })
}

export function useAppeal(appealId: string | null) {
  return useQuery({
    queryKey: ['admin', 'appeals', 'detail', appealId],
    queryFn: () => getAppeal(appealId!),
    enabled: !!appealId,
    placeholderData: keepPreviousData,
  })
}

export function useAppealStats() {
  return useQuery({
    queryKey: ['admin', 'appeals', 'stats'],
    queryFn: () => getAppealStats(),
    staleTime: 60_000,
  })
}

// ============================================================
// Reports — list + detail
// ============================================================

export function useReports(params: ReportsListParams) {
  return useQuery({
    queryKey: ['admin', 'reports', 'list', params],
    queryFn: () => listReports(params),
    placeholderData: keepPreviousData,
    staleTime: 30_000,
  })
}

export function useReport(reportId: string | null) {
  return useQuery({
    queryKey: ['admin', 'reports', 'detail', reportId],
    queryFn: () => getReport(reportId!),
    enabled: !!reportId,
    placeholderData: keepPreviousData,
  })
}

export function useReportStats() {
  return useQuery({
    queryKey: ['admin', 'reports', 'stats'],
    queryFn: () => getReportStats(),
    staleTime: 60_000,
  })
}

// ============================================================
// Mutations
// ============================================================

export function useAppealStatusMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ appealId, payload }: { appealId: string; payload: AppealStatusUpdate }) =>
      updateAppealStatus(appealId, payload),
    onSuccess: (updated) => {
      queryClient.setQueryData(['admin', 'appeals', 'detail', updated.id], updated)
      queryClient.invalidateQueries({ queryKey: ['admin', 'appeals', 'list'] })
      queryClient.invalidateQueries({ queryKey: ['admin', 'appeals', 'stats'] })
    },
  })
}

export function useReportStatusMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ reportId, payload }: { reportId: string; payload: ReportStatusUpdate }) =>
      updateReportStatus(reportId, payload),
    onSuccess: (updated) => {
      queryClient.setQueryData(['admin', 'reports', 'detail', updated.id], updated)
      queryClient.invalidateQueries({ queryKey: ['admin', 'reports', 'list'] })
      queryClient.invalidateQueries({ queryKey: ['admin', 'reports', 'stats'] })
    },
  })
}

export function useAppealPostActionMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ appealId, payload }: { appealId: string; payload: PostActionUpdate }) =>
      applyAppealPostAction(appealId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'appeals'] })
    },
  })
}

export function useReportPostActionMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ reportId, payload }: { reportId: string; payload: PostActionUpdate }) =>
      applyReportPostAction(reportId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'reports'] })
    },
  })
}

export function useSubmitAppealMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ postId, payload }: { postId: string; payload: AppealCreate }) =>
      submitAppeal(postId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'appeals'] })
      queryClient.invalidateQueries({ queryKey: ['admin', 'reports'] })
    },
  })
}

export function useSubmitReportMutation() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ postId, payload }: { postId: string; payload: ReportCreate }) =>
      submitReport(postId, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'appeals'] })
      queryClient.invalidateQueries({ queryKey: ['admin', 'reports'] })
    },
  })
}
