import { useMutation, useQueryClient } from '@tanstack/react-query'
import { createPlace, deletePlace, updatePlace } from '../api/places'
import type { PlaceCreatePayload, PlaceRead, PlaceUpdatePayload } from '../types/place'

/** POST /api/v1/admin/places then invalidate the places list cache. */
export function useCreatePlace() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (payload: PlaceCreatePayload) => createPlace(payload),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'places'] })
    },
  })
}

/** PUT /api/v1/admin/places/{id} then invalidate the places list cache. */
export function useUpdatePlace() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: PlaceUpdatePayload }) =>
      updatePlace(id, payload),
    onSuccess: (updated: PlaceRead) => {
      queryClient.invalidateQueries({
        queryKey: ['admin', 'places'],
      })
      // Refresh any cached list row that still holds the old value.
      queryClient.setQueriesData<{ items: PlaceRead[] }[]>(
        { queryKey: ['admin', 'places'] },
        (old) =>
          old?.map((page) => ({
            ...page,
            items: page.items.map((item) => (item.id === updated.id ? updated : item)),
          })),
      )
    },
  })
}

/** DELETE /api/v1/admin/places/{id} then invalidate the places list cache. */
export function useDeletePlace() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => deletePlace(id),
    onSuccess: () => {
      queryClient.invalidateQueries({
        queryKey: ['admin', 'places'],
      })
    },
  })
}