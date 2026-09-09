import { apiRequest } from './client'
import type {
  WalletLookup,
  WalletRecharge,
  WalletRechargeDetail,
  WalletRechargeListParams,
  WalletRechargeListResponse,
  WalletRechargePayload,
  WalletRechargeStats,
  WalletReports,
  WalletTransferListParams,
  WalletTransferListResponse,
} from '../types/wallet'

const base = '/api/v1/admin/wallet'

function buildQuery(params: WalletRechargeListParams): string {
  const q = new URLSearchParams()
  q.set('offset', String(params.offset))
  q.set('limit', String(params.limit))
  if (params.wallet_number) q.set('wallet_number', params.wallet_number)
  if (params.user_id) q.set('user_id', params.user_id)
  if (params.admin_id !== undefined) q.set('admin_id', String(params.admin_id))
  if (params.status) q.set('status', params.status)
  if (params.created_from) q.set('created_from', params.created_from)
  if (params.created_to) q.set('created_to', params.created_to)
  if (params.search && params.search.trim() !== '') q.set('search', params.search.trim())
  return q.toString()
}

/** `GET /api/v1/admin/wallet/lookup` — by wallet_number OR user_id. */
export function lookupWallet(params: { wallet_number?: string; user_id?: string }): Promise<WalletLookup> {
  const q = new URLSearchParams()
  if (params.wallet_number) q.set('wallet_number', params.wallet_number)
  if (params.user_id) q.set('user_id', params.user_id)
  return apiRequest<WalletLookup>(`${base}/lookup?${q.toString()}`)
}

/** `POST /api/v1/admin/wallet/recharge` — idempotency/transaction handled by the backend. */
export function rechargeWallet(payload: WalletRechargePayload): Promise<WalletRecharge> {
  return apiRequest<WalletRecharge>(`${base}/recharge`, {
    method: 'POST',
    body: payload,
  })
}

/** `GET /api/v1/admin/wallet/recharges/stats`. */
export function getRechargeStats(created_from?: string, created_to?: string): Promise<WalletRechargeStats> {
  const q = new URLSearchParams()
  if (created_from) q.set('created_from', created_from)
  if (created_to) q.set('created_to', created_to)
  const suffix = q.toString() ? `?${q.toString()}` : ''
  return apiRequest<WalletRechargeStats>(`${base}/recharges/stats${suffix}`)
}

/** `GET /api/v1/admin/wallet/recharges`. */
export function listRecharges(params: WalletRechargeListParams): Promise<WalletRechargeListResponse> {
  return apiRequest<WalletRechargeListResponse>(`${base}/recharges?${buildQuery(params)}`)
}

/** `GET /api/v1/admin/wallet/recharges/{id}`. */
export function getRecharge(rechargeId: string): Promise<WalletRechargeDetail> {
  return apiRequest<WalletRechargeDetail>(`${base}/recharges/${encodeURIComponent(rechargeId)}`)
}

/** `GET /api/v1/admin/wallet/reports` — aggregated wallet statistics. */
export function getWalletReports(created_from?: string, created_to?: string): Promise<WalletReports> {
  const q = new URLSearchParams()
  if (created_from) q.set('created_from', created_from)
  if (created_to) q.set('created_to', created_to)
  const suffix = q.toString() ? `?${q.toString()}` : ''
  return apiRequest<WalletReports>(`${base}/reports${suffix}`)
}

/** `GET /api/v1/admin/wallet/transfers` — list wallet transfers for admin monitoring. */
export function listTransfers(params: WalletTransferListParams): Promise<WalletTransferListResponse> {
  return apiRequest<WalletTransferListResponse>(`${base}/transfers?${buildTransferQuery(params)}`)
}

function buildTransferQuery(params: WalletTransferListParams): string {
  const q = new URLSearchParams()
  q.set('offset', String(params.offset))
  q.set('limit', String(params.limit))
  if (params.created_from) q.set('created_from', params.created_from)
  if (params.created_to) q.set('created_to', params.created_to)
  if (params.status) q.set('status', params.status)
  if (params.search && params.search.trim() !== '') q.set('search', params.search.trim())
  return q.toString()
}