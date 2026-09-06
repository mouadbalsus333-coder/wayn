import { useState } from 'react'
import { Loader2, Plus, X } from 'lucide-react'
import { accessMutationError, useAddPermissionMutation, useRemovePermissionMutation } from '../../hooks/useAdminUserAccessMutations'
import { useAdminUserDirectPermissions, usePermissionCatalog } from '../../hooks/useAdminUserAccess'

/**
 * Direct permissions of an admin user, managed through the real endpoints
 * `POST/DELETE /admin/users/{id}/permissions/{permissionId}` with the real
 * permission catalog from `GET /admin/permissions` (no mock data).
 */
export function AdminUserPermissions({ userId }: { userId: number }) {
  const permissionsQuery = useAdminUserDirectPermissions(userId)
  const catalogQuery = usePermissionCatalog()
  const addMutation = useAddPermissionMutation()
  const removeMutation = useRemovePermissionMutation()
  const [selectedId, setSelectedId] = useState<string>('')

  if (permissionsQuery.isPending || catalogQuery.isPending) {
    return (
      <section className="info-card access-card">
        <h3>الصلاحيات المباشرة</h3>
        <div className="state-panel state-panel-inline">
          <Loader2 className="spin" size={20} />
          <p>جارٍ تحميل الصلاحيات…</p>
        </div>
      </section>
    )
  }

  if (permissionsQuery.isError || !permissionsQuery.data) {
    return (
      <section className="info-card access-card">
        <h3>الصلاحيات المباشرة</h3>
        <div className="state-panel state-panel-error state-panel-inline">
          <p>{permissionsQuery.error instanceof Error ? permissionsQuery.error.message : 'تعذر تحميل الصلاحيات المباشرة.'}</p>
          <button type="button" className="ghost-button" onClick={() => permissionsQuery.refetch()}>إعادة المحاولة</button>
        </div>
      </section>
    )
  }

  const direct = permissionsQuery.data
  const catalog = catalogQuery.data ?? []
  const directIds = new Set(direct.map((permission) => permission.id))
  const available = catalog.filter((permission) => !directIds.has(permission.id))
  const mutationError = accessMutationError(addMutation.error) ?? accessMutationError(removeMutation.error)

  return (
    <section className="info-card access-card">
      <h3>الصلاحيات المباشرة ({direct.length})</h3>

      {direct.length > 0 ? (
        <div className="services-list">
          {direct.map((permission) => (
            <span key={permission.id} className="service-chip" title={permission.description ?? undefined}>
              {permission.name}
              <button
                type="button"
                className="chip-remove"
                aria-label={`إزالة الصلاحية ${permission.name}`}
                disabled={removeMutation.isPending}
                onClick={() => removeMutation.mutate({ userId, permissionId: permission.id })}
              >
                <X size={12} />
              </button>
            </span>
          ))}
        </div>
      ) : (
        <p className="muted">لا توجد صلاحيات مباشرة معيّنة لهذا المستخدم.</p>
      )}

      {catalogQuery.isError ? (
        <p className="mutation-error">تعذر تحميل قائمة الصلاحيات المتاحة — لن يمكن الإضافة الآن.</p>
      ) : available.length > 0 ? (
        <div className="access-add-row">
          <select
            aria-label="اختر صلاحية للإضافة"
            value={selectedId}
            onChange={(event) => setSelectedId(event.target.value)}
            disabled={addMutation.isPending}
          >
            <option value="">— اختر صلاحية —</option>
            {available.map((permission) => (
              <option key={permission.id} value={permission.id}>
                {permission.name}
              </option>
            ))}
          </select>
          <button
            type="button"
            className="primary-button"
            disabled={addMutation.isPending || selectedId === ''}
            onClick={() => {
              const permissionId = Number.parseInt(selectedId, 10)
              if (!Number.isFinite(permissionId)) return
              addMutation.mutate(
                { userId, permissionId },
                { onSuccess: () => setSelectedId('') },
              )
            }}
          >
            {addMutation.isPending ? <Loader2 className="spin" size={15} /> : <Plus size={15} />}
            إضافة صلاحية
          </button>
        </div>
      ) : (
        <p className="muted">جميع صلاحيات الـ Catalog معيّنة بالفعل.</p>
      )}

      {mutationError && <p className="mutation-error">{mutationError}</p>}
    </section>
  )
}