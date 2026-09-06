import { useState } from 'react'
import { Loader2, Plus, X } from 'lucide-react'
import { accessMutationError, useRemoveRoleMutation } from '../../hooks/useAdminUserAccessMutations'
import { useAdminUserRoles } from '../../hooks/useAdminUserAccess'

/**
 * Roles assigned to an admin user. Removal uses the real
 * `DELETE /admin/users/{id}/roles/{roleId}` endpoint.
 *
 * Limitation: the backend has no endpoint listing all available roles
 * (`GET /admin/roles` does not exist), so adding a role is not offered
 * — there is no real source for role ids and mock data is forbidden.
 */
export function AdminUserRoles({ userId }: { userId: number }) {
  const { data: roles, isPending, isError, error, refetch } = useAdminUserRoles(userId)
  const removeMutation = useRemoveRoleMutation()
  const [confirmRemove, setConfirmRemove] = useState<{ id: number; name: string } | null>(null)

  if (isPending) {
    return (
      <section className="info-card access-card">
        <h3>الأدوار</h3>
        <div className="state-panel state-panel-inline">
          <Loader2 className="spin" size={20} />
          <p>جارٍ تحميل الأدوار…</p>
        </div>
      </section>
    )
  }

  if (isError || !roles) {
    return (
      <section className="info-card access-card">
        <h3>الأدوار</h3>
        <div className="state-panel state-panel-error state-panel-inline">
          <p>{error instanceof Error ? error.message : 'تعذر تحميل الأدوار.'}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}>إعادة المحاولة</button>
        </div>
      </section>
    )
  }

  const mutationError = accessMutationError(removeMutation.error)

  return (
    <section className="info-card access-card">
      <h3>الأدوار ({roles.length})</h3>
      {roles.length > 0 ? (
        <div className="services-list">
          {roles.map((role) => (
            <span key={role.id} className={`service-chip${role.is_active ? '' : ' service-chip-muted'}`} title={role.description ?? undefined}>
              {role.name}
              <button
                type="button"
                className="chip-remove"
                aria-label={`إزالة الدور ${role.name}`}
                disabled={removeMutation.isPending}
                onClick={() => setConfirmRemove({ id: role.id, name: role.name })}
              >
                <X size={12} />
              </button>
            </span>
          ))}
        </div>
      ) : (
        <p className="muted">لا توجد أدوار معيّنة لهذا المستخدم.</p>
      )}

      <div className="access-limitation">
        <Plus size={14} />
        <span>
          إضافة دور غير متاحة: لا يوجد endpoint في الـ Backend لجلب قائمة الأدوار المتاحة
          (لا يوجد <code dir="ltr">GET /admin/roles</code>)، ولا تُستخدم بيانات وهمية.
        </span>
      </div>

      {mutationError && <p className="mutation-error">{mutationError}</p>}

      {confirmRemove && (
        <div className="modal-backdrop" role="presentation">
          <div className="modal" role="dialog" aria-modal="true">
            <h3>تأكيد إزالة الدور</h3>
            <p>
              سيتم إزالة الدور «{confirmRemove.name}» من هذا المستخدم، وستُنهى جلسته الحالية
              (يتم تحديث <code dir="ltr">token_version</code> في الـ Backend).
              {confirmRemove.name === 'super_admin' && (
                <strong> تحذير: إزالة دور super_admin قد تُفقد الوصول الإداري — الـ Backend لا يمنع ذلك تلقائيًا.</strong>
              )}
              هل أنت متأكد؟
            </p>
            <div className="modal-actions">
              <button type="button" className="ghost-button" onClick={() => setConfirmRemove(null)} disabled={removeMutation.isPending}>
                إلغاء
              </button>
              <button
                type="button"
                className="danger-button"
                disabled={removeMutation.isPending}
                onClick={() => {
                  removeMutation.mutate(
                    { userId, roleId: confirmRemove.id },
                    { onSuccess: () => setConfirmRemove(null) },
                  )
                }}
              >
                {removeMutation.isPending && <Loader2 className="spin" size={15} />}
                إزالة الدور
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}