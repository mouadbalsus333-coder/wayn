import { useMutation, useQueryClient } from '@tanstack/react-query'
import { rechargeWallet } from '../api/wallet'
import type { WalletRecharge, WalletRechargePayload } from '../types/wallet'

/**
 * Recharge is a financial operation.
 *
 * The backend is the single source of truth:
 * - It computes balances, applies the change and writes the ledger entry in
 *   one atomic transaction.
 * - It owns idempotency via an optional `idempotency_key` + a unique DB index.
 *
 * This frontend therefore:
 * - does NOT invent its own idempotency mechanism,
 * - does NOT optimistic-update the balance,
 * - does NOT auto-retry the request (no automatic retry on failure/timeout),
 * - disables the submit button while the request is in flight,
 * - refetches the log + stats only after a real successful response.
 *
 * The modal disables its buttons while `isPending`, so a double SSH-style
 * submit cannot fire two requests. No success is shown until the response
 * resolves successfully.
 */
export function useRechargeMutation() {
  const queryClient = useQueryClient()

  return useMutation<WalletRecharge, Error, WalletRechargePayload>({
    mutationFn: (payload) => rechargeWallet(payload),
    retry: false,
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'wallet'] })
    },
  })
}