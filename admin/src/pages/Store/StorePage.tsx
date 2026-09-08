import { useState } from 'react'
import { Loader2, Pencil, Plus, RefreshCw, Save, Store as StoreIcon, Trash2, Upload } from 'lucide-react'
import { userFacingError, ApiError } from '../../api/errors'
import { useStoreBanners, useStoreCategories, useStoreItems } from '../../hooks/useStore'
import {
  useCreateStoreBannerMutation,
  useCreateStoreCategoryMutation,
  useCreateStoreItemMutation,
  useDeleteStoreBannerMutation,
  useDeleteStoreCategoryMutation,
  useDeleteStoreItemMutation,
  useUpdateStoreBannerMutation,
  useUpdateStoreCategoryMutation,
  useUpdateStoreItemMutation,
} from '../../hooks/useStoreMutations'
import { uploadStoreImage } from '../../api/store'
import { useAuth } from '../../auth/useAuth'
import { permissions } from '../../permissions/permissionNames'
import { formatDate } from '../../lib/format'
import type { StoreBannerRead, StoreCategoryRead, StoreItemRead } from '../../types/store'
import './store.css'
import '../Places/places.css'
import '../Places/place-actions.css'

type Tab = 'categories' | 'items' | 'banners'

/** Admin Store management (`store.read` / `store.write` / `store.delete`). */
export function StorePage() {
  const { hasPermission } = useAuth()
  const canWrite = hasPermission(permissions.storeWrite)
  const canDelete = hasPermission(permissions.storeDelete)

  const [tab, setTab] = useState<Tab>('categories')

  return (
    <div className="store-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة المحتوى</p>
          <h2>المتجر</h2>
          <p className="muted">إدارة فئات المتجر والعناصر واللافتات الإعلانية.</p>
        </div>
      </header>

      <div className="store-tabs" role="tablist">
        {(
          [
            ['categories', 'الفئات'],
            ['items', 'العناصر'],
            ['banners', 'اللافتات'],
          ] as const
        ).map(([key, label]) => (
          <button
            key={key}
            type="button"
            role="tab"
            aria-selected={tab === key}
            className={tab === key ? 'store-tab active' : 'store-tab'}
            onClick={() => setTab(key)}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'categories' && <CategoriesTab canWrite={canWrite} canDelete={canDelete} />}
      {tab === 'items' && <ItemsTab canWrite={canWrite} canDelete={canDelete} />}
      {tab === 'banners' && <BannersTab canWrite={canWrite} canDelete={canDelete} />}
    </div>
  )
}

// ============================================================
// Store Categories
// ============================================================

function CategoriesTab({ canWrite, canDelete }: { canWrite: boolean; canDelete: boolean }) {
  const { data, isPending, isError, error, refetch } = useStoreCategories()
  const deleteMutation = useDeleteStoreCategoryMutation()
  const [editing, setEditing] = useState<StoreCategoryRead | 'new' | null>(null)
  const [deleting, setDeleting] = useState<StoreCategoryRead | null>(null)

  return (
    <>
      <div className="list-toolbar">
        {canWrite && (
          <button type="button" className="primary-button" onClick={() => setEditing('new')}>
            <Plus size={16} /> فئة متجر جديدة
          </button>
        )}
      </div>
      {isPending ? (
        <div className="state-panel card"><Loader2 className="spin" size={28} /><p>جارٍ التحميل…</p></div>
      ) : isError ? (
        <div className="state-panel card">
          <p>{userFacingError(error, 'تعذر تحميل فئات المتجر.')}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}><RefreshCw size={16} /> إعادة المحاولة</button>
        </div>
      ) : data && data.length === 0 ? (
        <div className="state-panel card"><StoreIcon size={26} /><p>لا توجد فئات متجر بعد.</p></div>
      ) : (
        <div className="table-wrap">
          <table className="places-table">
            <thead>
              <tr><th>الاسم (عربي)</th><th>الاسم (إنجليزي)</th><th>الترتيب</th><th>الحالة</th><th>الإنشاء</th><th>الإجراء</th></tr>
            </thead>
            <tbody>
              {data?.map((c) => (
                <tr key={c.id}>
                  <td>{c.name_ar}</td>
                  <td className="cell-muted">{c.name_en}</td>
                  <td>{c.sort_order}</td>
                  <td>{c.is_active ? <span className="badge badge-active">نشطة</span> : <span className="badge badge-inactive">غير نشطة</span>}</td>
                  <td className="cell-muted">{formatDate(c.created_at)}</td>
                  <td>
                    <div className="actions-inline">
                      {canWrite && (
                        <button type="button" className="ghost-button icon-button" aria-label={`تعديل ${c.name_ar}`} onClick={() => setEditing(c)}>
                          <Pencil size={16} />
                        </button>
                      )}
                      {canDelete && (
                        <button type="button" className="ghost-button icon-button danger-icon" aria-label={`حذف ${c.name_ar}`} onClick={() => setDeleting(c)}>
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

      {editing && <CategoryModal category={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && (
        <DeleteModal
          title="حذف فئة المتجر"
          message={`سيتم حذف فئة المتجر «${deleting.name_ar}». إذا منع الـ Backend العملية سيظهر خطؤه هنا.`}
          isPending={deleteMutation.isPending}
          isError={deleteMutation.isError}
          error={deleteMutation.error}
          onCancel={() => setDeleting(null)}
          onConfirm={() => deleteMutation.mutate(deleting.id, { onSuccess: () => setDeleting(null) })}
        />
      )}
    </>
  )
}

function CategoryModal({ category, onClose }: { category: StoreCategoryRead | null; onClose: () => void }) {
  const createMutation = useCreateStoreCategoryMutation()
  const updateMutation = useUpdateStoreCategoryMutation()
  const mutation = category ? updateMutation : createMutation

  const [nameAr, setNameAr] = useState(category?.name_ar ?? '')
  const [nameEn, setNameEn] = useState(category?.name_en ?? '')
  const [descAr, setDescAr] = useState(category?.description_ar ?? '')
  const [descEn, setDescEn] = useState(category?.description_en ?? '')
  const [imageUrl, setImageUrl] = useState(category?.image_url ?? '')
  const [sortOrder, setSortOrder] = useState(String(category?.sort_order ?? 0))
  const [isActive, setIsActive] = useState(category?.is_active ?? true)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const confirm = () => {
    const errors: Record<string, string> = {}
    if (!nameAr.trim()) errors.nameAr = 'الاسم العربي مطلوب'
    if (!nameEn.trim()) errors.nameEn = 'الاسم الإنجليزي مطلوب'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const shared = {
      name_ar: nameAr.trim(),
      name_en: nameEn.trim(),
      description_ar: descAr.trim() || null,
      description_en: descEn.trim() || null,
      image_url: imageUrl.trim() || null,
      sort_order: Number(sortOrder) || 0,
      is_active: isActive,
    }
    if (category === null) {
      createMutation.mutate(shared, { onSuccess: onClose })
    } else {
      updateMutation.mutate({ id: category.id, payload: shared }, { onSuccess: onClose })
    }
  }

  return (
    <FormModal
      title={category ? 'تعديل فئة المتجر' : 'فئة متجر جديدة'}
      onClose={onClose}
      onConfirm={confirm}
      isPending={mutation.isPending}
      error={mutation.isError ? mutation.error : null}
    >
      <div className="form-field">
        <label htmlFor="sc-ar">الاسم العربي *</label>
        <input id="sc-ar" value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
        {fieldErrors.nameAr && <span className="field-error">{fieldErrors.nameAr}</span>}
      </div>
      <div className="form-field">
        <label htmlFor="sc-en">الاسم الإنجليزي *</label>
        <input id="sc-en" dir="ltr" value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
        {fieldErrors.nameEn && <span className="field-error">{fieldErrors.nameEn}</span>}
      </div>
      <div className="form-field">
        <label htmlFor="sc-dar">الوصف (عربي)</label>
        <textarea id="sc-dar" value={descAr} onChange={(e) => setDescAr(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="sc-den">الوصف (إنجليزي)</label>
        <textarea id="sc-den" value={descEn} onChange={(e) => setDescEn(e.target.value)} />
      </div>
      <ImageField id="sc-img" label="الصورة" value={imageUrl} onChange={setImageUrl} />
      <div className="form-field">
        <label htmlFor="sc-order">الترتيب</label>
        <input id="sc-order" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
      </div>
      <div className="form-field">
        <label className="form-toggle">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
          نشطة
        </label>
      </div>
    </FormModal>
  )
}

function FormModal({
  title,
  children,
  onClose,
  onConfirm,
  isPending,
  error,
  confirmLabel = 'حفظ',
}: {
  title: string
  children: React.ReactNode
  onClose: () => void
  onConfirm: () => void
  isPending: boolean
  error: unknown
  confirmLabel?: string
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal modal-wide" role="dialog" aria-modal="true">
        <h3>{title}</h3>
        {error !== null && (
          <div className="mutation-error" role="alert">{userFacingError(error)}</div>
        )}
        <div className="form-grid">{children}</div>
        <div className="modal-actions">
          <button type="button" className="ghost-button" disabled={isPending} onClick={onClose}>
            إلغاء
          </button>
          <button type="button" className="primary-button" disabled={isPending} onClick={onConfirm}>
            {isPending ? <Loader2 className="spin" size={16} /> : <Save size={16} />}
            {isPending ? 'جارٍ الحفظ…' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}

/** Text input for an image URL + real upload via `POST /admin/store/media/image`. */
function ImageField({
  id,
  label,
  value,
  onChange,
}: {
  id: string
  label: string
  value: string
  onChange: (url: string) => void
}) {
  const [uploading, setUploading] = useState(false)
  const [uploadError, setUploadError] = useState<string | null>(null)

  const handleFile = async (file: File) => {
    setUploading(true)
    setUploadError(null)
    try {
      const { image_url } = await uploadStoreImage(file)
      onChange(image_url)
    } catch (e) {
      setUploadError(e instanceof ApiError ? e.message : 'تعذر رفع الصورة.')
    } finally {
      setUploading(false)
    }
  }

  return (
    <div className="form-field">
      <label htmlFor={id}>{label}</label>
      <div className="image-field-row">
        <input id={id} dir="ltr" value={value} onChange={(e) => onChange(e.target.value)} />
        <label className="ghost-button image-upload-button" htmlFor={`${id}-file`}>
          {uploading ? <Loader2 className="spin" size={16} /> : <Upload size={16} />}
          رفع
          <input
            id={`${id}-file`}
            type="file"
            accept="image/*"
            disabled={uploading}
            onChange={(e) => {
              const file = e.target.files?.[0]
              if (file) void handleFile(file)
              e.target.value = ''
            }}
          />
        </label>
      </div>
      {uploadError && <span className="field-error">{uploadError}</span>}
    </div>
  )
}

function DeleteModal({
  title,
  message,
  isPending,
  isError,
  error,
  onCancel,
  onConfirm,
}: {
  title: string
  message: string
  isPending: boolean
  isError: boolean
  error: unknown
  onCancel: () => void
  onConfirm: () => void
}) {
  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal" role="dialog" aria-modal="true">
        <h3>{title}</h3>
        <p>{message}</p>
        {isError && (
          <div className="mutation-error" role="alert">{userFacingError(error)}</div>
        )}
        <div className="modal-actions">
          <button type="button" className="ghost-button" disabled={isPending} onClick={onCancel}>
            إلغاء
          </button>
          <button type="button" className="danger-button" disabled={isPending} onClick={onConfirm}>
            {isPending ? <Loader2 className="spin" size={16} /> : <Trash2 size={16} />}
            {isPending ? 'جارٍ الحذف…' : 'حذف'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ============================================================
// Store Items
// ============================================================

const ITEM_TYPES: { value: StoreItemType; label: string }[] = [
  { value: 'AVATAR', label: 'صورة رمزية' },
  { value: 'FRAME', label: 'إطار' },
]
const CURRENCIES: { value: StoreCurrency; label: string }[] = [
  { value: 'POINTS', label: 'نقاط' },
  { value: 'COINS', label: 'عملات' },
]

function ItemsTab({ canWrite, canDelete }: { canWrite: boolean; canDelete: boolean }) {
  const { data, isPending, isError, error, refetch } = useStoreItems()
  const categoriesQuery = useStoreCategories()
  const deleteMutation = useDeleteStoreItemMutation()
  const [editing, setEditing] = useState<StoreItemRead | 'new' | null>(null)
  const [deleting, setDeleting] = useState<StoreItemRead | null>(null)

  const categoryName = (id: string) => categoriesQuery.data?.find((c) => c.id === id)?.name_ar ?? id

  return (
    <>
      <div className="list-toolbar">
        {canWrite && (
          <button type="button" className="primary-button" onClick={() => setEditing('new')} disabled={categoriesQuery.isPending}>
            <Plus size={16} /> عنصر جديد
          </button>
        )}
      </div>
      {isPending ? (
        <div className="state-panel card"><Loader2 className="spin" size={28} /><p>جارٍ التحميل…</p></div>
      ) : isError ? (
        <div className="state-panel card">
          <p>{userFacingError(error, 'تعذر تحميل عناصر المتجر.')}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}><RefreshCw size={16} /> إعادة المحاولة</button>
        </div>
      ) : data && data.length === 0 ? (
        <div className="state-panel card"><StoreIcon size={26} /><p>لا توجد عناصر بعد.</p></div>
      ) : (
        <div className="table-wrap">
          <table className="places-table">
            <thead>
              <tr><th>الاسم</th><th>النوع</th><th>السعر</th><th>الفئة</th><th>المخزون</th><th>الحالة</th><th>الإجراء</th></tr>
            </thead>
            <tbody>
              {data?.map((item) => (
                <tr key={item.id}>
                  <td>{item.name_ar}</td>
                  <td>{ITEM_TYPES.find((t) => t.value === item.item_type)?.label ?? item.item_type}</td>
                  <td>{item.price} {CURRENCIES.find((c) => c.value === item.currency)?.label ?? item.currency}</td>
                  <td className="cell-muted">{categoryName(item.category_id)}</td>
                  <td>{item.stock ?? '—'}</td>
                  <td>{item.is_active ? <span className="badge badge-active">نشط</span> : <span className="badge badge-inactive">غير نشط</span>}</td>
                  <td>
                    <div className="actions-inline">
                      {canWrite && (
                        <button type="button" className="ghost-button icon-button" aria-label={`تعديل ${item.name_ar}`} onClick={() => setEditing(item)}>
                          <Pencil size={16} />
                        </button>
                      )}
                      {canDelete && (
                        <button type="button" className="ghost-button icon-button danger-icon" aria-label={`حذف ${item.name_ar}`} onClick={() => setDeleting(item)}>
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

      {editing && <ItemModal item={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && (
        <DeleteModal
          title="حذف عنصر المتجر"
          message={`سيتم حذف العنصر «${deleting.name_ar}». إذا منع الـ Backend العملية (مثل عنصر مُشترى) سيظهر خطؤه هنا.`}
          isPending={deleteMutation.isPending}
          isError={deleteMutation.isError}
          error={deleteMutation.error}
          onCancel={() => setDeleting(null)}
          onConfirm={() => deleteMutation.mutate(deleting.id, { onSuccess: () => setDeleting(null) })}
        />
      )}
    </>
  )
}

function ItemModal({ item, onClose }: { item: StoreItemRead | null; onClose: () => void }) {
  const categoriesQuery = useStoreCategories()
  const createMutation = useCreateStoreItemMutation()
  const updateMutation = useUpdateStoreItemMutation()
  const mutation = item ? updateMutation : createMutation

  const [categoryId, setCategoryId] = useState(item?.category_id ?? '')
  const [nameAr, setNameAr] = useState(item?.name_ar ?? '')
  const [nameEn, setNameEn] = useState(item?.name_en ?? '')
  const [descAr, setDescAr] = useState(item?.description_ar ?? '')
  const [itemType, setItemType] = useState<StoreItemType>(item?.item_type ?? 'AVATAR')
  const [currency, setCurrency] = useState<StoreCurrency>(item?.currency ?? 'POINTS')
  const [price, setPrice] = useState(String(item?.price ?? 0))
  const [imageUrl, setImageUrl] = useState(item?.image_url ?? '')
  const [stock, setStock] = useState(item?.stock != null ? String(item.stock) : '')
  const [sortOrder, setSortOrder] = useState(String(item?.sort_order ?? 0))
  const [isActive, setIsActive] = useState(item?.is_active ?? true)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const confirm = () => {
    const errors: Record<string, string> = {}
    if (!categoryId) errors.categoryId = 'الفئة مطلوبة'
    if (!nameAr.trim()) errors.nameAr = 'الاسم العربي مطلوب'
    if (!nameEn.trim()) errors.nameEn = 'الاسم الإنجليزي مطلوب'
    if (price.trim() === '' || Number.isNaN(Number(price))) errors.price = 'سعر غير صالح'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const shared = {
      category_id: categoryId,
      name_ar: nameAr.trim(),
      name_en: nameEn.trim(),
      description_ar: descAr.trim() || null,
      item_type: itemType,
      currency,
      price: Number(price),
      image_url: imageUrl.trim() || null,
      stock: stock.trim() === '' ? null : Number(stock),
      sort_order: Number(sortOrder) || 0,
      is_active: isActive,
    }
    if (item === null) {
      createMutation.mutate(shared, { onSuccess: onClose })
    } else {
      updateMutation.mutate({ id: item.id, payload: shared }, { onSuccess: onClose })
    }
  }

  return (
    <FormModal
      title={item ? 'تعديل عنصر المتجر' : 'عنصر جديد'}
      onClose={onClose}
      onConfirm={confirm}
      isPending={mutation.isPending}
      error={mutation.isError ? mutation.error : null}
    >
      <div className="form-field">
        <label htmlFor="si-cat">الفئة *</label>
        <select id="si-cat" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
          <option value="">— اختر —</option>
          {categoriesQuery.data?.map((c) => (
            <option key={c.id} value={c.id}>{c.name_ar}</option>
          ))}
        </select>
        {fieldErrors.categoryId && <span className="field-error">{fieldErrors.categoryId}</span>}
      </div>
      <div className="form-field">
        <label htmlFor="si-type">النوع *</label>
        <select id="si-type" value={itemType} onChange={(e) => setItemType(e.target.value as StoreItemType)}>
          {ITEM_TYPES.map((t) => (
            <option key={t.value} value={t.value}>{t.label}</option>
          ))}
        </select>
      </div>
      <div className="form-field">
        <label htmlFor="si-ar">الاسم العربي *</label>
        <input id="si-ar" value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
        {fieldErrors.nameAr && <span className="field-error">{fieldErrors.nameAr}</span>}
      </div>
      <div className="form-field">
        <label htmlFor="si-en">الاسم الإنجليزي *</label>
        <input id="si-en" dir="ltr" value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
        {fieldErrors.nameEn && <span className="field-error">{fieldErrors.nameEn}</span>}
      </div>
      <div className="form-field full">
        <label htmlFor="si-dar">الوصف (عربي)</label>
        <textarea id="si-dar" value={descAr} onChange={(e) => setDescAr(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="si-currency">العملة *</label>
        <select id="si-currency" value={currency} onChange={(e) => setCurrency(e.target.value as StoreCurrency)}>
          {CURRENCIES.map((c) => (
            <option key={c.value} value={c.value}>{c.label}</option>
          ))}
        </select>
      </div>
      <div className="form-field">
        <label htmlFor="si-price">السعر *</label>
        <input id="si-price" type="number" min="0" step="any" value={price} onChange={(e) => setPrice(e.target.value)} />
        {fieldErrors.price && <span className="field-error">{fieldErrors.price}</span>}
      </div>
      <div className="form-field full">
        <ImageField id="si-img" label="الصورة" value={imageUrl} onChange={setImageUrl} />
      </div>
      <div className="form-field">
        <label htmlFor="si-stock">المخزون (فارغ = غير محدود)</label>
        <input id="si-stock" type="number" value={stock} onChange={(e) => setStock(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="si-order">الترتيب</label>
        <input id="si-order" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
      </div>
      <div className="form-field">
        <label className="form-toggle">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
          نشط
        </label>
      </div>
    </FormModal>
  )
}

// ============================================================
// Store Banners
// ============================================================

function BannersTab({ canWrite, canDelete }: { canWrite: boolean; canDelete: boolean }) {
  const { data, isPending, isError, error, refetch } = useStoreBanners()
  const deleteMutation = useDeleteStoreBannerMutation()
  const [editing, setEditing] = useState<StoreBannerRead | 'new' | null>(null)
  const [deleting, setDeleting] = useState<StoreBannerRead | null>(null)

  return (
    <>
      <div className="list-toolbar">
        {canWrite && (
          <button type="button" className="primary-button" onClick={() => setEditing('new')}>
            <Plus size={16} /> لافتة جديدة
          </button>
        )}
      </div>
      {isPending ? (
        <div className="state-panel card"><Loader2 className="spin" size={28} /><p>جارٍ التحميل…</p></div>
      ) : isError ? (
        <div className="state-panel card">
          <p>{userFacingError(error, 'تعذر تحميل اللافتات.')}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}><RefreshCw size={16} /> إعادة المحاولة</button>
        </div>
      ) : data && data.length === 0 ? (
        <div className="state-panel card"><StoreIcon size={26} /><p>لا توجد لافتات بعد.</p></div>
      ) : (
        <div className="table-wrap">
          <table className="places-table">
            <thead>
              <tr><th>العنوان (عربي)</th><th>الحالة</th><th>الترتيب</th><th>الفترة</th><th>الإجراء</th></tr>
            </thead>
            <tbody>
              {data?.map((b) => (
                <tr key={b.id}>
                  <td>{b.title_ar}</td>
                  <td>{b.is_active ? <span className="badge badge-active">نشطة</span> : <span className="badge badge-inactive">غير نشطة</span>}</td>
                  <td>{b.sort_order}</td>
                  <td className="cell-muted">
                    {b.starts_at ? formatDate(b.starts_at) : '—'} → {b.ends_at ? formatDate(b.ends_at) : '—'}
                  </td>
                  <td>
                    <div className="actions-inline">
                      {canWrite && (
                        <button type="button" className="ghost-button icon-button" aria-label={`تعديل ${b.title_ar}`} onClick={() => setEditing(b)}>
                          <Pencil size={16} />
                        </button>
                      )}
                      {canDelete && (
                        <button type="button" className="ghost-button icon-button danger-icon" aria-label={`حذف ${b.title_ar}`} onClick={() => setDeleting(b)}>
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

      {editing && <BannerModal banner={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
      {deleting && (
        <DeleteModal
          title="حذف اللافتة"
          message={`سيتم حذف اللافتة «${deleting.title_ar}». هل أنت متأكد؟`}
          isPending={deleteMutation.isPending}
          isError={deleteMutation.isError}
          error={deleteMutation.error}
          onCancel={() => setDeleting(null)}
          onConfirm={() => deleteMutation.mutate(deleting.id, { onSuccess: () => setDeleting(null) })}
        />
      )}
    </>
  )
}

function BannerModal({ banner, onClose }: { banner: StoreBannerRead | null; onClose: () => void }) {
  const createMutation = useCreateStoreBannerMutation()
  const updateMutation = useUpdateStoreBannerMutation()
  const mutation = banner ? updateMutation : createMutation

  const [titleAr, setTitleAr] = useState(banner?.title_ar ?? '')
  const [titleEn, setTitleEn] = useState(banner?.title_en ?? '')
  const [bodyAr, setBodyAr] = useState(banner?.body_ar ?? '')
  const [bodyEn, setBodyEn] = useState(banner?.body_en ?? '')
  const [imageUrl, setImageUrl] = useState(banner?.image_url ?? '')
  const [targetUrl, setTargetUrl] = useState(banner?.target_url ?? '')
  const [sortOrder, setSortOrder] = useState(String(banner?.sort_order ?? 0))
  const [startsAt, setStartsAt] = useState(banner?.starts_at ? banner.starts_at.slice(0, 16) : '')
  const [endsAt, setEndsAt] = useState(banner?.ends_at ? banner.ends_at.slice(0, 16) : '')
  const [isActive, setIsActive] = useState(banner?.is_active ?? true)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const confirm = () => {
    const errors: Record<string, string> = {}
    if (!titleAr.trim()) errors.titleAr = 'العنوان العربي مطلوب'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const toIso = (v: string) => (v.trim() === '' ? null : new Date(v).toISOString())
    const shared = {
      title_ar: titleAr.trim(),
      title_en: titleEn.trim() || null,
      body_ar: bodyAr.trim() || null,
      body_en: bodyEn.trim() || null,
      image_url: imageUrl.trim() || null,
      target_url: targetUrl.trim() || null,
      sort_order: Number(sortOrder) || 0,
      starts_at: toIso(startsAt),
      ends_at: toIso(endsAt),
      is_active: isActive,
    }
    if (banner === null) {
      createMutation.mutate(shared, { onSuccess: onClose })
    } else {
      updateMutation.mutate({ id: banner.id, payload: shared }, { onSuccess: onClose })
    }
  }

  return (
    <FormModal
      title={banner ? 'تعديل اللافتة' : 'لافتة جديدة'}
      onClose={onClose}
      onConfirm={confirm}
      isPending={mutation.isPending}
      error={mutation.isError ? mutation.error : null}
    >
      <div className="form-field">
        <label htmlFor="sb-ar">العنوان (عربي) *</label>
        <input id="sb-ar" value={titleAr} onChange={(e) => setTitleAr(e.target.value)} />
        {fieldErrors.titleAr && <span className="field-error">{fieldErrors.titleAr}</span>}
      </div>
      <div className="form-field">
        <label htmlFor="sb-en">العنوان (إنجليزي)</label>
        <input id="sb-en" dir="ltr" value={titleEn} onChange={(e) => setTitleEn(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="sb-bar">النص (عربي)</label>
        <textarea id="sb-bar" value={bodyAr} onChange={(e) => setBodyAr(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="sb-ben">النص (إنجليزي)</label>
        <textarea id="sb-ben" value={bodyEn} onChange={(e) => setBodyEn(e.target.value)} />
      </div>
      <div className="form-field full">
        <ImageField id="sb-img" label="صورة اللافتة" value={imageUrl} onChange={setImageUrl} />
      </div>
      <div className="form-field">
        <label htmlFor="sb-target">رابط الهدف</label>
        <input id="sb-target" dir="ltr" value={targetUrl} onChange={(e) => setTargetUrl(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="sb-order">الترتيب</label>
        <input id="sb-order" type="number" value={sortOrder} onChange={(e) => setSortOrder(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="sb-start">بداية العرض</label>
        <input id="sb-start" dir="ltr" type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} />
      </div>
      <div className="form-field">
        <label htmlFor="sb-end">نهاية العرض</label>
        <input id="sb-end" dir="ltr" type="datetime-local" value={endsAt} onChange={(e) => setEndsAt(e.target.value)} />
      </div>
      <div className="form-field">
        <label className="form-toggle">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
          نشطة
        </label>
      </div>
    </FormModal>
  )
}
