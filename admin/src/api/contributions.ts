import { apiRequest } from './client'
import type {
  ContributionApprovePayload,
  ContributionListParams,
  ContributionListResponse,
  ContributionRead,
  ContributionRejectPayload,
} from '../types/contribution'

const base = '/api/v1/admin/contributions'

export function listContributions(params: ContributionListParams): Promise<ContributionListResponse> {
  const searchParams = new URLSearchParams()
  searchParams.set('offset', String(params.offset))
  searchParams.set('limit', String(params.limit))
  if (params.status) searchParams.set('status', params.status)
  if (params.contribution_type) searchParams.set('contribution_type', params.contribution_type)
  return apiRequest<ContributionListResponse>(`${base}?${searchParams.toString()}`)
}

export function approveContribution(id: string, payload: ContributionApprovePayload): Promise<ContributionRead> {
  return apiRequest<ContributionRead>(`${base}/${encodeURIComponent(id)}/approve`, {
    method: 'POST',
    body: payload,
  })
}

export function rejectContribution(id: string, payload: ContributionRejectPayload): Promise<ContributionRead> {
  return apiRequest<ContributionRead>(`${base}/${encodeURIComponent(id)}/reject`, {
    method: 'POST',
    body: payload,
  })
}