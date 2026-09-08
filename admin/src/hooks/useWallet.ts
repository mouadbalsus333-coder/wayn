import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { getRechargeStats, getWalletReports, listRecharges, listTransfers } from '../api/wallet'
import type { WalletRechargeListParams, WalletTransferListParams } from '../types/wallet'

export function useRecharges(params: WalletRechargeListParams) {
  return useQuery({
    queryKey: ['admin', 'wallet', 'recharges', params],
    queryFn: () => listRecharges(params),
    placeholderData: keepPreviousData,
  })
}

export function useRechargeStats(created_from?: string, created_to?: string) {
  return useQuery({
    queryKey: ['admin', 'wallet', 'stats', created_from, created_to],
    queryFn: () => getRechargeStats(created_from, created_to),
  })
}

export function useWalletReports(created_from?: string, created_to?: string) {
  return useQuery({
    queryKey: ['admin', 'wallet', 'reports', created_from, created_to],
    queryFn: () => getWalletReports(created_from, created_to),
  })
}

export function useTransfers(params: WalletTransferListParams) {
  return useQuery({
    queryKey: ['admin', 'wallet', 'transfers', params],
    queryFn: () => listTransfers(params),
    placeholderData: keepPreviousData,
  })
}