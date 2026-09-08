import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  createStoreBanner,
  createStoreCategory,
  createStoreItem,
  deleteStoreBanner,
  deleteStoreCategory,
  deleteStoreItem,
  updateStoreBanner,
  updateStoreCategory,
  updateStoreItem,
} from '../api/store'
import type {
  StoreBannerCreatePayload,
  StoreBannerUpdatePayload,
  StoreCategoryCreatePayload,
  StoreCategoryUpdatePayload,
  StoreItemCreatePayload,
  StoreItemUpdatePayload,
} from '../types/store'

function invalidateStore(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: ['admin', 'store'] })
}

// ---- Categories ----
export function useCreateStoreCategoryMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (p: StoreCategoryCreatePayload) => createStoreCategory(p), onSuccess: () => invalidateStore(qc) })
}
export function useUpdateStoreCategoryMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: ({ id, payload }: { id: string; payload: StoreCategoryUpdatePayload }) => updateStoreCategory(id, payload), onSuccess: () => invalidateStore(qc) })
}
export function useDeleteStoreCategoryMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (id: string) => deleteStoreCategory(id), onSuccess: () => invalidateStore(qc) })
}

// ---- Items ----
export function useCreateStoreItemMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (p: StoreItemCreatePayload) => createStoreItem(p), onSuccess: () => invalidateStore(qc) })
}
export function useUpdateStoreItemMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: ({ id, payload }: { id: string; payload: StoreItemUpdatePayload }) => updateStoreItem(id, payload), onSuccess: () => invalidateStore(qc) })
}
export function useDeleteStoreItemMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (id: string) => deleteStoreItem(id), onSuccess: () => invalidateStore(qc) })
}

// ---- Banners ----
export function useCreateStoreBannerMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (p: StoreBannerCreatePayload) => createStoreBanner(p), onSuccess: () => invalidateStore(qc) })
}
export function useUpdateStoreBannerMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: ({ id, payload }: { id: string; payload: StoreBannerUpdatePayload }) => updateStoreBanner(id, payload), onSuccess: () => invalidateStore(qc) })
}
export function useDeleteStoreBannerMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (id: string) => deleteStoreBanner(id), onSuccess: () => invalidateStore(qc) })
}