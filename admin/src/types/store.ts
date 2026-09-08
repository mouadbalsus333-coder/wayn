/**
 * Admin Store module.
 * Mirrors `backend/app/schemas/store.py` and the enums in
 * `backend/app/models/store_item.py`.
 */

export const STORE_ITEM_TYPES = ['AVATAR', 'FRAME'] as const
export type StoreItemType = (typeof STORE_ITEM_TYPES)[number]

export const STORE_CURRENCIES = ['POINTS', 'COINS'] as const
export type StoreCurrency = (typeof STORE_CURRENCIES)[number]

// ============================================================
// Store Categories
// ============================================================

export type StoreCategoryRead = {
  id: string
  name_ar: string
  name_en: string
  description_ar: string | null
  description_en: string | null
  icon_url: string | null
  image_url: string | null
  sort_order: number
  is_active: boolean
  created_at: string
  updated_at: string
}

export type StoreCategoryCreatePayload = {
  name_ar: string
  name_en: string
  description_ar?: string | null
  description_en?: string | null
  icon_url?: string | null
  image_url?: string | null
  sort_order?: number
  is_active?: boolean
}

export type StoreCategoryUpdatePayload = {
  name_ar?: string | null
  name_en?: string | null
  description_ar?: string | null
  description_en?: string | null
  icon_url?: string | null
  image_url?: string | null
  sort_order?: number | null
  is_active?: boolean | null
}

// ============================================================
// Store Items
// ============================================================

export type StoreItemRead = {
  id: string
  category_id: string
  name_ar: string
  name_en: string
  description_ar: string | null
  description_en: string | null
  item_type: StoreItemType
  currency: StoreCurrency
  price: number
  image_url: string | null
  asset_id: string | null
  duration_days: number | null
  available_from: string | null
  available_until: string | null
  ownership_duration_days: number | null
  stock: number | null
  sort_order: number
  is_active: boolean
  created_at: string
  updated_at: string
}

export type StoreItemCreatePayload = {
  category_id: string
  name_ar: string
  name_en: string
  description_ar?: string | null
  description_en?: string | null
  item_type: StoreItemType
  currency: StoreCurrency
  price: number
  image_url?: string | null
  asset_id?: string | null
  duration_days?: number | null
  available_from?: string | null
  available_until?: string | null
  ownership_duration_days?: number | null
  stock?: number | null
  sort_order?: number
  is_active?: boolean
}

export type StoreItemUpdatePayload = {
  category_id?: string | null
  name_ar?: string | null
  name_en?: string | null
  description_ar?: string | null
  description_en?: string | null
  item_type?: StoreItemType | null
  currency?: StoreCurrency | null
  price?: number | null
  image_url?: string | null
  asset_id?: string | null
  duration_days?: number | null
  available_from?: string | null
  available_until?: string | null
  ownership_duration_days?: number | null
  stock?: number | null
  sort_order?: number | null
  is_active?: boolean | null
}

// ============================================================
// Store Banners
// ============================================================

export type StoreBannerRead = {
  id: string
  title_ar: string | null
  title_en: string | null
  image_url: string
  target_url: string | null
  sort_order: number
  is_active: boolean
  starts_at: string | null
  ends_at: string | null
  created_at: string
  updated_at: string
}

export type StoreBannerCreatePayload = {
  title_ar?: string | null
  title_en?: string | null
  image_url: string
  target_url?: string | null
  sort_order?: number
  is_active?: boolean
  starts_at?: string | null
  ends_at?: string | null
}

export type StoreBannerUpdatePayload = {
  title_ar?: string | null
  title_en?: string | null
  image_url?: string | null
  target_url?: string | null
  sort_order?: number | null
  is_active?: boolean | null
  starts_at?: string | null
  ends_at?: string | null
}