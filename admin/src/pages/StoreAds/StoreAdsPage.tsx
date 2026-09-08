import { useState } from 'react'
import {
  ArrowDown,
  ArrowUp,
  Eye,
  EyeOff,
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Save,
  Megaphone,
  Timer,
  Trash2,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { formatDate } from '../../lib/format'
import { useStoreBanners } from '../../hooks/useStore'
import {
  useCreateStoreBannerMutation,
  useDeleteStoreBannerMutation,
  useUpdateStoreBannerMutation,
} from '../../hooks/useStoreMutations'
import { useAuth } from '../../auth/useAuth'
import {
  useStoreAdsSettings,
  useUpdateStoreAdsSettingsMutation,
} from '../../hooks/useStoreAdsSettings'
import { DeleteModal, ImageField } from '../Store/StorePage'
import type { StoreBannerRead } from '../../types/store'
import '../Store/store.css'
import '../Places/places.css'
import '../Places/place-actions.css'

const ROTATION_MIN = 2
const ROTATION_MAX = 60

// ============================================================
// Ad lifecycle status (aligned with the backend visibility rule:
// shows while `starts_at <= now` and `ends_at >= now`, UTC).
// ============================================================

type AdStatus = 'active' | 'scheduled' | 'expired' | 'inactive'

function adStatus(ad: StoreBannerRead, nowMs: number): AdStatus {
  if (!ad.is_active) return 'inactive'
  const start = ad.starts_at ? Date.parse(ad.starts_at) : null
  const end = ad.ends_at ? Date.parse(ad.ends_at) : null
  if (start !== null && nowMs < start) return 'scheduled'
  if (end !== null && nowMs > end) return 'expired'
  return 'active'
}

const AD_STATUS_META: Record<AdStatus, { label: string; badge: string }> = {
  active: { label: 'فعال', badge: 'badge badge-active' },
  scheduled: { label: 'مجدول', badge: 'badge badge-scheduled' },
  expired: { label: 'منتهي', badge: 'badge badge-expired' },
  inactive: { label: 'غير فعال', badge: 'badge badge-muted' },
}

/** Store ads management (`store.read` / `store.write` / `store.delete`). */
export function StoreAdsPage() {
  const { hasPermission } = useAuth()
  const canWrite = hasPermission('store.write')
  const canDelete = hasPermission('store.delete')

  return (
    <div className="permissions-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">المتجر</p>
          <h2>إعلانات المتجر</h2>
          <p className="muted">
            إدارة الإعلانات المتحركة التي تظهر داخل المتجر في التطبيق، ومدة الانتقال بينها.
          </p>
        </div>
      </header>
      <RotationSettingsCard />
      <AdsTable canWrite={canWrite} canDelete={canDelete} />
    </div>
  )
}

// ============================================================
// Rotation settings card
// ============================================================

function RotationSettingsCard() {
  const settingsQuery = useStoreAdsSettings()
  const updateMutation = useUpdateStoreAdsSettingsMutation()
  const [value, setValue] = useState('')
  const [fieldError, setFieldError] = useState<string | null>(null)
  const [saved, setSaved] = useState(false)

  const current = value !== '' ? value : settingsQuery.data ? String(settingsQuery.data.rotation_seconds) : ''

  const save = () => {
    const parsed = Number(current)
    if (current.trim() === '' || !Number.isInteger(parsed) || parsed < ROTATION_MIN || parsed > ROTATION_MAX) {
      setFieldError(`أدخل عددًا صحيحًا بين ${ROTATION_MIN} و ${ROTATION_MAX} ثانية.`)
      return
    }
    setFieldError(null)
    updateMutation.mutate(
      { rotation_seconds: parsed },
      { onSuccess: () => { setValue(''); setSaved(true) } },
    )
  }

  return (
    <section className="card ads-settings-card">
      <div className="ads-settings-head">
        <Timer size={18} />
        <h3>إعدادات عرض الإعلانات</h3>
      </div>
      {settingsQuery.isPending ? (
        <p className="muted">جارٍ تحميل الإعدادات…</p>
      ) : settingsQuery.isError ? (
        <div className="state-panel state-panel-error state-panel-inline">
          <p>{userFacingError(settingsQuery.error, 'تعذر تحميل الإعدادات.')}</p>
          <button type="button" className="ghost-button" onClick={() => settingsQuery.refetch()}>
            <RefreshCw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : (
        <div className="ads-settings-row">
          <div className="form-field">
            <label htmlFor="ads-rotation">مدة الانتقال بين الإعلانات بالثواني</label>
            <input
              id="ads-rotation"
              dir="ltr"
              type="number"
              min={ROTATION_MIN}
              max={ROTATION_MAX}
              value={current}
              onChange={(e) => setValue(e.target.value)}
            />
            {fieldError && <span className="field-error">{fieldError}</span>}
          </div>
          <button type="button" className="primary-button" disabled={updateMutation.isPending} onClick={save}>
            {updateMutation.isPending ? <Loader2 className="spin" size={16} /> : <Save size={16} />}
            حفظ
          </button>
          {updateMutation.isError && (
            <span className="field-error">{userFacingError(updateMutation.error)}</span>
          )}
          {saved && !updateMutation.isError && <span className="muted">تم الحفظ ✓</span>}
        </div>
      )}
    </section>
  )
}

// ============================================================
// Ads table
// ============================================================

function AdsTable({ canWrite, canDelete }: { canWrite: boolean; canDelete: boolean }) {
  const { data, isPending, isError, error, refetch } = useStoreBanners()
  const deleteMutation = useDeleteStoreBannerMutation()
  const updateMutation = useUpdateStoreBannerMutation()
  const [editing, setEditing] = useState<StoreBannerRead | 'new' | null>(null)
  const [deleting, setDeleting] = useState<StoreBannerRead | null>(null)

  const ads = (data ?? []).slice().sort((a, b) => a.sort_order - b.sort_order)

  const move = (ad: StoreBannerRead, direction: -1 | 1) => {
    const index = ads.findIndex((item) => item.id === ad.id)
    const target = ads[index + direction]
    if (target === undefined) return
    updateMutation.mutate({ id: ad.id, payload: { sort_order: target.sort_order } })
    updateMutation.mutate({ id: target.id, payload: { sort_order: ad.sort_order } })
  }

  return (
    <>
      <div className="places-table-toolbar">
        <button
          type="button"
          className="primary-button"
          disabled={!canWrite}
          title={canWrite ? undefined : 'يتطلب صلاحية store.write'}
          onClick={() => setEditing('new')}
        >
          <Plus size={17} /> إضافة إعلان
        </button>
        <button type="button" className="ghost-button" onClick={() => refetch()}>
          <RefreshCw size={16} /> تحديث
        </button>
      </div>

      {isPending ? (
        <div className="state-panel card">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل الإعلانات…</p>
        </div>
      ) : isError ? (
        <div className="state-panel card">
          <p>{userFacingError(error, 'تعذر تحميل الإعلانات.')}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}>
            <RefreshCw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : ads.length === 0 ? (
        <div className="state-panel card">
          <Megaphone size={26} />
          <p>لا توجد إعلانات بعد. أضف أول إعلان ليظهر في المتجر.</p>
        </div>
      ) : (
        <div className="table-wrap">
          <table className="places-table">
            <thead>
              <tr>
                <th>الصورة</th>
                <th>الترتيب</th>
                <th>الرابط</th>
                <th>الفترة</th>
                <th>الحالة</th>
                <th>أُنشئ في</th>
                <th>الإجراء</th>
              </tr>
            </thead>
            <tbody>
              {ads.map((ad) => (
                <AdRow
                  key={ad.id}
                  ad={ad}
                  isFirst={ad.id === ads[0]?.id}
                  isLast={ad.id === ads[ads.length - 1]?.id}
                  canWrite={canWrite}
                  canDelete={canDelete}
                  movePending={updateMutation.isPending}
                  onMove={move}
                  onToggle={() =>
                    updateMutation.mutate({ id: ad.id, payload: { is_active: !ad.is_active } })
                  }
                  onEdit={() => setEditing(ad)}
                  onDelete={() => setDeleting(ad)}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}

      {editing !== null && (
        <AdFormModal
          ad={editing === 'new' ? null : editing}
          nextSortOrder={(ads[ads.length - 1]?.sort_order ?? 0) + 1}
          onClose={() => setEditing(null)}
        />
      )}
      {deleting !== null && (
        <DeleteModal
          title="حذف الإعلان"
          message="هل أنت متأكد من حذف هذا الإعلان؟ الحذف نهائي ولا يمكن التراجع عنه."
          isPending={deleteMutation.isPending}
          isError={deleteMutation.isError}
          error={deleteMutation.error}
          onCancel={() => setDeleting(null)}
          onConfirm={() =>
            deleteMutation.mutate(deleting.id, { onSuccess: () => setDeleting(null) })
          }
        />
      )}
    </>
  )
}

function AdRow({
  ad,
  isFirst,
  isLast,
  canWrite,
  canDelete,
  movePending,
  onMove,
  onToggle,
  onEdit,
  onDelete,
}: {
  ad: StoreBannerRead
  isFirst: boolean
  isLast: boolean
  canWrite: boolean
  canDelete: boolean
  movePending: boolean
  onMove: (ad: StoreBannerRead, direction: -1 | 1) => void
  onToggle: () => void
  onEdit: () => void
  onDelete: () => void
}) {
  return (
    <tr>
      <td>
        {ad.image_url ? <img src={ad.image_url} alt="إعلان" className="ads-thumb" /> : '—'}
      </td>
      <td>{ad.sort_order}</td>
      <td className="cell-muted">
        {ad.target_url ? (
          <a href={ad.target_url} target="_blank" rel="noreferrer" dir="ltr">
            {ad.target_url}
          </a>
        ) : (
          '—'
        )}
      </td>
      <td className="cell-muted">
        {ad.starts_at ? formatDate(ad.starts_at) : '—'} {'→'} {ad.ends_at ? formatDate(ad.ends_at) : 'بدون انتهاء'}
      </td>
      <td>
        <span className={AD_STATUS_META[adStatus(ad, Date.now())].badge}>
          {AD_STATUS_META[adStatus(ad, Date.now())].label}
        </span>
      </td>
      <td className="cell-muted">{new Date(ad.created_at).toLocaleDateString('ar')}</td>
      <td>
        <div className="actions-inline">
          <button
            type="button"
            className="ghost-button icon-button"
            aria-label="تحريك لأعلى"
            disabled={!canWrite || movePending || isFirst}
            onClick={() => onMove(ad, -1)}
          >
            <ArrowUp size={16} />
          </button>
          <button
            type="button"
            className="ghost-button icon-button"
            aria-label="تحريك لأسفل"
            disabled={!canWrite || movePending || isLast}
            onClick={() => onMove(ad, 1)}
          >
            <ArrowDown size={16} />
          </button>
          <button
            type="button"
            className="ghost-button icon-button"
            aria-label={ad.is_active ? 'تعطيل' : 'تفعيل'}
            disabled={!canWrite || movePending}
            onClick={onToggle}
          >
            {ad.is_active ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
          <button
            type="button"
            className="ghost-button icon-button"
            aria-label="تعديل"
            disabled={!canWrite}
            onClick={onEdit}
          >
            <Pencil size={16} />
          </button>
          <button
            type="button"
            className="ghost-button icon-button danger-icon"
            aria-label="حذف"
            disabled={!canDelete}
            onClick={onDelete}
          >
            <Trash2 size={16} />
          </button>
        </div>
      </td>
    </tr>
  )
}

// ============================================================
// Create / edit modal
// ============================================================

function AdFormModal({
  ad,
  nextSortOrder,
  onClose,
}: {
  ad: StoreBannerRead | null
  nextSortOrder: number
  onClose: () => void
}) {
  const createMutation = useCreateStoreBannerMutation()
  const updateMutation = useUpdateStoreBannerMutation()
  const mutation = ad === null ? createMutation : updateMutation

  const [imageUrl, setImageUrl] = useState(ad?.image_url ?? '')
  const [targetUrl, setTargetUrl] = useState(ad?.target_url ?? '')
  const [sortOrder, setSortOrder] = useState(String(ad?.sort_order ?? nextSortOrder))
  const [startsAt, setStartsAt] = useState(ad?.starts_at ? ad.starts_at.slice(0, 16) : '')
  const [endsAt, setEndsAt] = useState(ad?.ends_at ? ad.ends_at.slice(0, 16) : '')
  const [isActive, setIsActive] = useState(ad?.is_active ?? true)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const confirm = () => {
    const errors: Record<string, string> = {}
    if (imageUrl.trim() === '') errors.image = 'صورة الإعلان مطلوبة'
    if (targetUrl.trim() !== '' && !/^https?:\/\/\S+\.\S+/.test(targetUrl.trim())) {
      errors.target = 'أدخل رابطًا صحيحًا يبدأ بـ http:// أو https://'
    }
    const parsedSort = Number(sortOrder)
    if (!Number.isInteger(parsedSort) || parsedSort < 0) errors.sort = 'أدخل ترتيبًا صحيحًا'
    const toIso = (value: string) => (value.trim() === '' ? null : new Date(value).toISOString())
    const startIso = toIso(startsAt)
    const endIso = toIso(endsAt)
    if (startIso !== null && endIso !== null && endIso < startIso) {
      errors.window = 'تاريخ النهاية يجب ألا يكون قبل تاريخ البداية'
    }
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const payload = {
      image_url: imageUrl.trim(),
      target_url: targetUrl.trim() === '' ? null : targetUrl.trim(),
      sort_order: parsedSort,
      starts_at: startIso,
      ends_at: endIso,
      is_active: isActive,
    }
    if (ad === null) {
      createMutation.mutate(payload, { onSuccess: onClose })
    } else {
      updateMutation.mutate({ id: ad.id, payload }, { onSuccess: onClose })
    }
  }

  return (
    <div className="modal-backdrop" role="presentation">
      <div className="modal" role="dialog" aria-modal="true">
        <h3>{ad === null ? 'إضافة إعلان' : 'تعديل الإعلان'}</h3>
        {mutation.isError && (
          <div className="mutation-error" role="alert">{userFacingError(mutation.error)}</div>
        )}
        <div className="form-grid">
          <ImageField id="ad-image" label="صورة الإعلان" value={imageUrl} onChange={setImageUrl} />
          {fieldErrors.image && <span className="field-error">{fieldErrors.image}</span>}
          {imageUrl.trim() !== '' && (
            <img src={imageUrl} alt="معاينة الإعلان" className="ads-thumb ads-preview" />
          )}
          <div className="form-field full">
            <label htmlFor="ad-target">رابط الإعلان (اختياري)</label>
            <input
              id="ad-target"
              dir="ltr"
              value={targetUrl}
              placeholder="https://example.com"
              onChange={(e) => setTargetUrl(e.target.value)}
            />
            {fieldErrors.target && <span className="field-error">{fieldErrors.target}</span>}
          </div>
          <div className="form-field full">
            <label htmlFor="ad-start">تاريخ بداية الإعلان (اختياري)</label>
            <input
              id="ad-start"
              dir="ltr"
              type="datetime-local"
              value={startsAt}
              onChange={(e) => setStartsAt(e.target.value)}
            />
          </div>
          <div className="form-field full">
            <label htmlFor="ad-end">تاريخ نهاية الإعلان (اتركه فارغًا = بلا انتهاء)</label>
            <input
              id="ad-end"
              dir="ltr"
              type="datetime-local"
              value={endsAt}
              onChange={(e) => setEndsAt(e.target.value)}
            />
            {fieldErrors.window && <span className="field-error">{fieldErrors.window}</span>}
          </div>
          <div className="form-field">
            <label htmlFor="ad-sort">ترتيب الإعلان</label>
            <input
              id="ad-sort"
              dir="ltr"
              type="number"
              min={0}
              value={sortOrder}
              onChange={(e) => setSortOrder(e.target.value)}
            />
            {fieldErrors.sort && <span className="field-error">{fieldErrors.sort}</span>}
          </div>
          <div className="form-field full ads-toggle-field">
            <label htmlFor="ad-active">الإعلان فعال (يظهر في التطبيق)</label>
            <input
              id="ad-active"
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
            />
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
