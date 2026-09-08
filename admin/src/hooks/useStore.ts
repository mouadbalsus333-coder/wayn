import { useQuery } from '@tanstack/react-query'
import { listStoreBanners, listStoreCategories, listStoreItems } from '../api/store'
import type { StoreBannerRead, StoreCategoryRead, StoreItemRead } from '../types/store'

export function useStoreCategories() {
  return useQuery<StoreCategoryRead[]>({
    queryKey: ['admin', 'store', 'categories'],
    queryFn: listStoreCategories,
  })
}

export function useStoreItems() {
  return useQuery<StoreItemRead[]>({
    queryKey: ['admin', 'store', 'items'],
    queryFn: listStoreItems,
  })
}

export function useStoreBanners() {
  return useQuery<StoreBannerRead[]>({
    queryKey: ['admin', 'store', 'banners'],
    queryFn: listStoreBanners,
  })
}