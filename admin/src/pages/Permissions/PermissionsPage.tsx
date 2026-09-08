import { useState } from 'react'
import {
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Save,
  ShieldCheck,
  Trash2,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { usePermissionCatalog } from '../../hooks/useAdminUserAccess'
import {
  useCreatePermissionMutation,
  useDeletePermissionMutation,
  useUpdatePermissionMutation,
} from '../../hooks/usePermissionMutations'
import type { PermissionCatalogItem } from '../../types/adminUser'
import './permissions.css'
import '../Places/places.css'
import '../Places/place-actions.css'

export function PermissionsPage() {
  const { data, isPending, isError, error, refetch } = usePermissionCatalog()
  const deleteMutation = useDeletePermissionMutation()

  const [editing, setEditing] = useState<PermissionCatalogItem | 'new' | null>(null)
  const [deleting, setDeleting] = useState<PermissionCatalogItem | null>(null)

  return (
    <div className="permissions-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة النظام</p>
          <h2>كتالوج الصلاحيات</h2>
          <p className="muted">إدارة أسماء الصلاحيات المستخدمة في النظام. متاحة لـ Super Admin فقط.</p>
        </div>
        <button type="button" className="primary-button" onClick={() => setEditing('new')}>
          <Plus size={17} /> صلاحية جديدة
        </button>
      </header>

      {isPending ? (
        <div className="state-panel card">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل الصلاحيات…</p>
        </div>
      ) : isError ? (
        <div className="state-panel card">
          <p>{userFacingError(error, 'تعذر تحميل الصلاحيات.')}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}>
            <RefreshCw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : data && data.length === 0 ? (
        <div className="state-panel card">
          <ShieldCheck size={26} />
          <p>لا توجد صلاحيات.</p>
        </div>
      ) : (
        <div className="table-wrap">
          <table className="places-table">
            <thead>
              <tr>
                <th>الاسم</th>
                <th>الوصف</th>
                <th>الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {data?.map((permission) => (
                <tr key={permission.id}>
                  <td><code dir="ltr">{permission.name}</code></td>
                  <td className="cell-muted">{permission.description ?? '—'}</td>
                  <td>
                    <div className="actions-inline">
                      <button
                        type="button"
                        className="ghost-button icon-button"
                        aria-label={`تعديل ${permission.name}`}
                        onClick={() => setEditing(permission)}
                      >
                        <Pencil size={16} />
                      </button>
                      <button
                        type="button"
                        className="ghost-button icon-button danger-icon"
                        aria-label={`حذف ${permission.name}`}
                        onClick={() => setDeleting(permission)}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {editing && (
        <PermissionEditor
          permission={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
        />
      )}
      {deleting && (
        <DeleteModal
          permission={deleting}
          mutation={deleteMutation}
          onClose={() => setDeleting(null)}
        />
      )}
    </div>
  )
}
function PermissionEditor({
  permission,
  onClose,
}: {
  permission: PermissionCatalogItem | null
  onClose: () => void
}) {
  const createMutation = useCreatePermissionMutation()
  const updateMutation = useUpdatePermissionMutation()
  const mutation = permission === null ? createMutation : updateMutation

  const [name, setName] = useState(permission?.name ?? '')
  const [description, setDescription] = useState(permission?.description ?? '')
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const confirm = () => {
    const errors: Record<string, string> = {}
    if (!name.trim()) errors.name = 'الاسم مطلوب'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const payload = {
      name: name.trim(),
      description: description.trim() === '' ? null : description.trim(),
    }
    if (permission === null) {
      createMutation.mutate(payload, { onSuccess: onClose })
    } else {
      updateMutation.mutate({ id: permission.id, payload }, { onSuccess: onClose })
    }
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal" role="dialog" aria-modal="true">
        <h3>{permission ? 'تعديل الصلاحية' : 'صلاحية جديدة'}</h3>
        {mutation.isError && (
          <div className="mutation-error" role="alert">{userFacingError(mutation.error)}</div>
        )}
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="perm-name">الاسم (مثل places.write)</label>
            <input id="perm-name" dir="ltr" value={name} onChange={(e) => setName(e.target.value)} placeholder="module.action" />
            {fieldErrors.name && <span className="field-error">{fieldErrors.name}</span>}
          </div>
          <div className="form-field full">
            <label htmlFor="perm-desc">الوصف</label>
            <textarea id="perm-desc" value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>
        </div>
        <div className="modal-actions">
          <button type="button" className="ghost-button" disabled={mutation.isPending} onClick={onClose}>
            إلغاء
          </button>
          <button type="button" className="primary-button" disabled={mutation.isPending} onClick={confirm}>
            {mutation.isPending ? <Loader2 className="spin" size={16} /> : <Save size={16} />}
            {mutation.isPending ? 'جارٍ الحفظ…' : 'حفظ'}
          </button>
        </div>
      </div>
    </div>
  )
}

function DeleteModal({
  permission,
  mutation,
  onClose,
}: {
  permission: PermissionCatalogItem
  mutation: { isError: boolean; isPending: boolean; error: unknown; mutate: (id: number, opts?: { onSuccess?: () => void }) => void }
  onClose: () => void
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal" role="dialog" aria-modal="true">
        <h3>حذف الصلاحية</h3>
        <p>
          سيتم حذف الصلاحية «{permission.name}». إذا كانت مرتبطة بأدوار أو مستخدمين فقد يرفض الـ Backend
          العملية، وسيظهر خطؤه هنا.
        </p>
        {mutation.isError && (
          <div className="mutation-error" role="alert">{userFacingError(mutation.error)}</div>
        )}
        <div className="modal-actions">
          <button type="button" className="ghost-button" disabled={mutation.isPending} onClick={onClose}>
            إلغاء
          </button>
          <button
            type="button"
            className="danger-button"
            disabled={mutation.isPending}
            onClick={() => mutation.mutate(permission.id, { onSuccess: onClose })}
          >
            {mutation.isPending ? <Loader2 className="spin" size={16} /> : <Trash2 size={16} />}
            {mutation.isPending ? 'جارٍ الحذف…' : 'حذف'}
          </button>
        </div>
      </div>
    </div>
  )
}