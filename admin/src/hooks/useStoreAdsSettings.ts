import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getStoreAdsSettings, updateStoreAdsSettings } from '../api/store'

const STORE_ADS_SETTINGS_KEY = ['admin', 'store-ads', 'settings'] as const

/** Store ads rotation settings (`GET/PUT /admin/store-ads/settings`). */
export function useStoreAdsSettings() {
  return useQuery({
    queryKey: STORE_ADS_SETTINGS_KEY,
    queryFn: getStoreAdsSettings,
  })
}

export function useUpdateStoreAdsSettingsMutation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (payload: { rotation_seconds: number }) => updateStoreAdsSettings(payload),
    onSuccess: (settings) => {
      qc.setQueryData(STORE_ADS_SETTINGS_KEY, settings)
    },
  })
}
