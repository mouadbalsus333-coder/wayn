import { useMutation, useQueryClient } from '@tanstack/react-query'
import { createPermission, deletePermission, updatePermission } from '../api/adminPermissions'
import type { PermissionCreatePayload, PermissionUpdatePayload } from '../types/permission'

/**
 * Permission catalog CRUD. The catalog is loaded by the existing
 * `usePermissionCatalog` hook (`useAdminUserAccess.ts`, query key
 * `['admin','permission-catalog']`). These mutations invalidate that key so
 * the Admin User permission picker stays in sync. All protected by
 * `super_admin` in the backend.
 */
const PERMISSION_CATALOG_KEY = ['admin', 'permission-catalog'] as const

function invalidateCatalog(queryClient: ReturnType<typeof useQueryClient>) {
  void queryClient.invalidateQueries({ queryKey: PERMISSION_CATALOG_KEY })
}

export function useCreatePermissionMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (p: PermissionCreatePayload) => createPermission(p), onSuccess: () => invalidateCatalog(qc) })
}

export function useUpdatePermissionMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: ({ id, payload }: { id: number; payload: PermissionUpdatePayload }) => updatePermission(id, payload), onSuccess: () => invalidateCatalog(qc) })
}

export function useDeletePermissionMutation() {
  const qc = useQueryClient()
  return useMutation({ mutationFn: (id: number) => deletePermission(id), onSuccess: () => invalidateCatalog(qc) })
}