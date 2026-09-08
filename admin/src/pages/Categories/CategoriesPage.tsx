import { useState } from 'react'
import {
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Save,
  Tags,
  Trash2,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useCategories } from '../../hooks/useCategories'
import {
  useCreateCategoryMutation,
  useDeleteCategoryMutation,
  useUpdateCategoryMutation,
} from '../../hooks/useCategoryMutations'
import { useAuth } from '../../auth/useAuth'
import { permissions } from '../../permissions/permissionNames'
import type { CategoryRead } from '../../types/category'
import './categories.css'
import '../Places/places.css'
import '../Places/place-actions.css'

export function CategoriesPage() {
  const { hasPermission } = useAuth()
  const canWrite = hasPermission(permissions.categoriesWrite)
  const canDelete = hasPermission(permissions.categoriesDelete)

  const { data, isPending, isError, error, refetch } = useCategories()
  const deleteMutation = useDeleteCategoryMutation()

  const [editing, setEditing] = useState<CategoryRead | 'new' | null>(null)
  const [deleting, setDeleting] = useState<CategoryRead | null>(null)

  return (
    <div className="categories-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة المحتوى</p>
          <h2>فئات الأماكن</h2>
          <p className="muted">إدارة تصنيفات الأماكن المعروضة داخل التطبيق.</p>
        </div>
        {canWrite && (
          <button type="button" className="primary-button" onClick={() => setEditing('new')}>
            <Plus size={17} /> فئة جديدة
          </button>
        )}
      </header>

      {isPending ? (
        <div className="state-panel card">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل الفئات…</p>
        </div>
      ) : isError ? (
        <div className="state-panel card">
          <p>{userFacingError(error, 'تعذر تحميل الفئات.')}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}>
            <RefreshCw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : data && data.length === 0 ? (
        <div className="state-panel card">
          <Tags size={26} />
          <p>لا توجد فئات بعد.</p>
        </div>
      ) : (
        <div className="table-wrap">
          <table className="places-table">
            <thead>
              <tr>
                <th>الاسم (عربي)</th>
                <th>الاسم (إنجليزي)</th>
                <th>الأيقونة</th>
                <th>الترتيب</th>
                <th>الحالة</th>
                <th>الفئة الأم</th>
                <th>الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {data?.map((category) => (
                <tr key={category.id}>
                  <td>{category.name_ar}</td>
                  <td className="cell-muted">{category.name_en ?? '—'}</td>
                  <td className="cell-muted">{category.icon ?? '—'}</td>
                  <td>{category.sort_order}</td>
                  <td>
                    {category.is_active ? (
                      <span className="badge badge-active">نشطة</span>
                    ) : (
                      <span className="badge badge-inactive">غير نشطة</span>
                    )}
                  </td>
                  <td className="cell-muted">{category.parent_id ?? '—'}</td>
                  <td>
                    <div className="actions-inline">
                      {canWrite && (
                        <button
                          type="button"
                          className="ghost-button icon-button"
                          aria-label={`تعديل ${category.name_ar}`}
                          onClick={() => setEditing(category)}
                        >
                          <Pencil size={16} />
                        </button>
                      )}
                      {canDelete && (
                        <button
                          type="button"
                          className="ghost-button icon-button danger-icon"
                          aria-label={`حذف ${category.name_ar}`}
                          onClick={() => setDeleting(category)}
                        >
                          <Trash2 size={16} />
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {editing && (
        <CategoryEditor
          category={editing === 'new' ? null : editing}
          categories={data ?? []}
          onClose={() => setEditing(null)}
        />
      )}
      {deleting && (
        <DeleteModal
          category={deleting}
          mutation={deleteMutation}
          onClose={() => setDeleting(null)}
        />
      )}
    </div>
  )
}
function CategoryEditor({
  category,
  categories,
  onClose,
}: {
  category: CategoryRead | null
  categories: CategoryRead[]
  onClose: () => void
}) {
  const createMutation = useCreateCategoryMutation()
  const updateMutation = useUpdateCategoryMutation()
  const mutation = category === null ? createMutation : updateMutation

  const [nameAr, setNameAr] = useState(category?.name_ar ?? '')
  const [nameEn, setNameEn] = useState(category?.name_en ?? '')
  const [icon, setIcon] = useState(category?.icon ?? '')
  const [sortOrder, setSortOrder] = useState(String(category?.sort_order ?? 0))
  const [isActive, setIsActive] = useState(category?.is_active ?? true)
  const [parentId, setParentId] = useState(category?.parent_id ?? '')
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const confirm = () => {
    const errors: Record<string, string> = {}
    if (!nameAr.trim()) errors.nameAr = 'الاسم العربي مطلوب'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const order = Number.isNaN(Number(sortOrder)) ? 0 : Number(sortOrder)
    if (category === null) {
      createMutation.mutate(
        {
          name_ar: nameAr.trim(),
          name_en: nameEn.trim() === '' ? null : nameEn.trim(),
          icon: icon.trim() === '' ? null : icon.trim(),
          sort_order: order,
          is_active: isActive,
          parent_id: parentId === '' ? null : parentId,
        },
        { onSuccess: onClose },
      )
    } else {
      updateMutation.mutate(
        {
          id: category.id,
          payload: {
            name_ar: nameAr.trim(),
            name_en: nameEn.trim() === '' ? null : nameEn.trim(),
            icon: icon.trim() === '' ? null : icon.trim(),
            is_active: isActive,
            parent_id: parentId === '' ? null : parentId,
            sort_order: order,
          },
        },
        { onSuccess: onClose },
      )
    }
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal modal-wide" role="dialog" aria-modal="true">
        <h3>{category ? 'تعديل الفئة' : 'فئة جديدة'}</h3>
        {mutation.isError && (
          <div className="mutation-error" role="alert">{userFacingError(mutation.error)}</div>
        )}
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="cat-name-ar">الاسم العربي</label>
            <input id="cat-name-ar" value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
            {fieldErrors.nameAr && <span className="field-error">{fieldErrors.nameAr}</span>}
          </div>
          <div className="form-field">
            <label htmlFor="cat-name-en">الاسم الإنجليزي</label>
            <input id="cat-name-en" value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="cat-icon">الأيقونة</label>
            <input id="cat-icon" value={icon} onChange={(e) => setIcon(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="cat-order">الترتيب</label>
            <input id="cat-order" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="cat-parent">الفئة الأم</label>
            <select id="cat-parent" value={parentId} onChange={(e) => setParentId(e.target.value)}>
              <option value="">بدون</option>
              {categories
                .filter((c) => !category || c.id !== category.id)
                .map((c) => (
                  <option key={c.id} value={c.id}>{c.name_ar}</option>
                ))}
            </select>
          </div>
          <div className="form-field">
            <label className="form-toggle">
              <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
              الفئة نشطة
            </label>
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
  category,
  mutation,
  onClose,
}: {
  category: CategoryRead
  mutation: { isError: boolean; isPending: boolean; error: unknown; mutate: (id: string, opts?: { onSuccess?: () => void }) => void }
  onClose: () => void
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal" role="dialog" aria-modal="true">
        <h3>حذف الفئة</h3>
        <p>
          سيتم حذف الفئة «{category.name_ar}». إذا كانت مستخدمة في أماكن فقد يرفض الـ Backend العملية،
          وسيظهر خطؤه هنا.
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
            onClick={() => mutation.mutate(category.id, { onSuccess: onClose })}
          >
            {mutation.isPending ? <Loader2 className="spin" size={16} /> : <Trash2 size={16} />}
            {mutation.isPending ? 'جارٍ الحذف…' : 'حذف'}
          </button>
        </div>
      </div>
    </div>
  )
}