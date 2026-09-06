import { Loader2, RefreshCw } from 'lucide-react'
import { useAdminUserDirectPermissions, useAdminUserResolvedPermissions, useAdminUserRoles } from '../../hooks/useAdminUserAccess'

/**
 * Shows the resolved permissions of an admin user (`GET /admin/users/{id}/resolved-permissions`)
 * alongside the direct ones. The backend response does not label the source of
 * each permission, so "derived from roles" is computed client-side as
 * (resolved − direct) and is clearly marked as a computed view.
 */
export function ResolvedPermissions({ userId }: { userId: number }) {
  const resolvedQuery = useAdminUserResolvedPermissions(userId)
  const directQuery = useAdminUserDirectPermissions(userId)
  const rolesQuery = useAdminUserRoles(userId)

  if (resolvedQuery.isPending) {
    return (
      <section className="info-card access-card">
        <h3>الصلاحيات الفعلية</h3>
        <div className="state-panel state-panel-inline">
          <Loader2 className="spin" size={20} />
          <p>جارٍ تحميل الصلاحيات الفعلية…</p>
        </div>
      </section>
    )
  }

  if (resolvedQuery.isError || !resolvedQuery.data) {
    return (
      <section className="info-card access-card">
        <h3>الصلاحيات الفعلية</h3>
        <div className="state-panel state-panel-error state-panel-inline">
          <p>{resolvedQuery.error instanceof Error ? resolvedQuery.error.message : 'تعذر تحميل الصلاحيات الفعلية.'}</p>
          <button type="button" className="ghost-button" onClick={() => resolvedQuery.refetch()}>
            <RefreshCw size={15} /> إعادة المحاولة
          </button>
        </div>
      </section>
    )
  }

  const resolved = resolvedQuery.data
  const directIds = new Set((directQuery.data ?? []).map((permission) => permission.id))
  const fromRoles = resolved.filter((permission) => !directIds.has(permission.id))

  return (
    <section className="info-card access-card">
      <h3>الصلاحيات الفعلية ({resolved.length})</h3>

      {resolved.length === 0 ? (
        <p className="muted">لا توجد صلاحيات فعلية لهذا الحساب حاليًا.</p>
      ) : (
        <>
          <div className="services-list">
            {resolved.map((permission) => (
              <span key={permission.id} className="service-chip" title={permission.description ?? undefined}>
                {permission.name}
              </span>
            ))}
          </div>

          <div className="resolved-breakdown">
            <p>
              <strong>من الأدوار</strong> ({rolesQuery.data?.filter((role) => role.is_active).length ?? '…'} أدوار نشطة):{' '}
              {fromRoles.length > 0 ? `${fromRoles.length} صلاحية محسوبة` : 'لا شيء'}
              <span className="muted"> (محسوبة: الفعليّة ناقص المباشرة — الـ API لا يميّز المصدر)</span>
            </p>
            <p>
              <strong>مباشرة</strong> ({directQuery.data?.length ?? '…'})
            </p>
          </div>
        </>
      )}
    </section>
  )
}