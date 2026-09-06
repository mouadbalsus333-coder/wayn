import { useQuery } from '@tanstack/react-query'
import { getPlaces } from '../api/places'
import type { AdminPlaceListParams } from '../types/place'

export function usePlaces(params: AdminPlaceListParams) {
  return useQuery({
    queryKey: ['admin', 'places', params],
    queryFn: () => getPlaces(params),
    placeholderData: (previous) => previous,
  })
}