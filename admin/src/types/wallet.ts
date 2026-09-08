/**
 * Admin Wallet Recharge module.
 * Mirrors `backend/app/api/routers/admin_wallet.py` and
 * `backend/app/models/wallet_admin_recharge.py`.
 */

export const RECHARGE_STATUSES = ['PENDING', 'CONFIRMED', 'FAILED'] as const
export type RechargeStatus = (typeof RECHARGE_STATUSES)[number]

/** Response of `GET /api/v1/admin/wallet/lookup`. */
export type WalletLookup = {
  user_id: string
  wallet_id: string
  wallet_number: string
  full_name: string
  username: string
  phone: string | null
  coins_balance: number
  wallet_status: string | null
  is_active: boolean
  is_verified: boolean
}

export type WalletRecharge = {
  recharge_id: string
  transaction_id: string
  user_id: string
  wallet_id: string
  wallet_number: string
  amount: number
  balance_before: number
  balance_after: number
  status: RechargeStatus
  admin_id: number
  admin_email: string
  created_at: string
}

/** Body of `POST /api/v1/admin/wallet/recharge`. */
export interface WalletRechargePayload {
  target_user_id: string
  amount: number
  note?: string | null
}

/** Response of `GET /api/v1/admin/wallet/recharges/stats`. */
export type WalletRechargeStats = {
  total_operations: number
  total_coins_recharged: number
  confirmed_count: number
  failed_count: number
}

/** Response of `GET /api/v1/admin/wallet/recharges`. */
export interface WalletRechargeListResponse {
  items: WalletRecharge[]
  total: number
  offset: number
  limit: number
}

/** Query params of `GET /api/v1/admin/wallet/recharges`. */
export interface WalletRechargeListParams {
  offset: number
  limit: number
  wallet_number?: string
  user_id?: string
  admin_id?: number
  status?: RechargeStatus
  created_from?: string
  created_to?: string
  search?: string
}

/** Response of `GET /api/v1/admin/wallet/recharges/{id}`. */
export type WalletRechargeDetail = WalletRecharge & {
  note: string | null
  idempotency_key: string | null
  ip_address: string | null
  user_agent: string | null
  user: { id: string; full_name: string; username: string; phone: string | null }
  admin: { id: number; email: string; full_name: string }
}

// ============================================================
// Wallet Reports
// ============================================================

/** Response of `GET /api/v1/admin/wallet/reports`. */
export type WalletReports = {
  period_start: string | null
  period_end: string | null
  total_recharges: number
  total_recharge_amount: number
  confirmed_recharges: number
  failed_recharges: number
  total_transfers: number
  confirmed_transfers: number
  failed_transfers: number
  total_transfer_amount: number
}

// ============================================================
// Wallet Transfers
// ============================================================

export const TRANSFER_STATUSES = ['PENDING', 'CONFIRMED', 'FAILED', 'REVERSED'] as const
export type TransferStatus = (typeof TRANSFER_STATUSES)[number]

export type WalletTransfer = {
  id: string
  sender_wallet_id: string
  receiver_wallet_id: string
  sender_wallet_number: string | null
  receiver_wallet_number: string | null
  sender_name: string | null
  receiver_name: string | null
  asset: string
  amount: number
  status: TransferStatus
  description: string | null
  created_at: string
  completed_at: string | null
}

export interface WalletTransferListResponse {
  items: WalletTransfer[]
  total: number
  offset: number
  limit: number
}

export interface WalletTransferListParams {
  offset: number
  limit: number
  created_from?: string
  created_to?: string
  status?: TransferStatus
  search?: string
}