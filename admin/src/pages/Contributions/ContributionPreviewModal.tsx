import type { ContributionRead, ContributionStatus, ContributionType } from '../../types/contribution'
import { ContributionPreviewMap } from './ContributionPreviewMap'

const TYPE_LABELS: Record<ContributionType, string> = {
  CREATE_PLACE: 'إنشاء مكان',
  UPDATE_PLACE: 'تعديل مكان',
  ADD_IMAGE: 'إضافة صورة',
  UPDATE_INFORMATION: 'تحديث معلومات',
  VERIFY_PLACE: 'التحقق من مكان',
}

const STATUS_LABELS: Record<ContributionStatus, string> = {
  PENDING: 'قيد الانتظار',
  APPROVED: 'معتمدة',
  REJECTED: 'مرفوضة',
  CANCELLED: 'ملغاة',
}

/** Fields of the CREATE_PLACE payload rendered in a fixed order. */
const PLACE_FIELDS: { key: string; label: string }[] = [
  { key: 'name', label: 'اسم المكان' },
  { key: 'category_name', label: 'التصنيف' },
  { key: 'city', label: 'المدينة' },
  { key: 'address', label: 'العنوان' },
  { key: 'description', label: 'الوصف' },
  { key: 'phone', label: 'الهاتف' },
  { key: 'website', label: 'الموقع الإلكتروني' },
  { key: 'facebook', label: 'Facebook' },
  { key: 'instagram', label: 'Instagram' },
  { key: 'tiktok', label: 'TikTok' },
  { key: 'youtube', label: 'YouTube' },
  { key: 'whatsapp', label: 'WhatsApp' },
  { key: 'image_url', label: 'الصورة الرئيسية' },
]

function asString(value: unknown): string | null {
  if (value === null || value === undefined) return null
  if (typeof value === 'string') return value.trim() === '' ? null : value
  if (typeof value === 'number' || typeof value === 'boolean') return String(value)
  return null
}

function toNumberOrNull(value: unknown): number | null {
  const n = typeof value === 'number' ? value : typeof value === 'string' ? Number(value) : NaN
  return Number.isFinite(n) ? n : null
}

function imageUrl(value: unknown): string | null {
  const s = asString(value)
  if (s === null) return null
  if (!/^https?:\/\//i.test(s)) return null
  return s
}

const URL_KEYS = new Set(['facebook', 'instagram', 'tiktok', 'youtube', 'whatsapp', 'website', 'image_url'])

/**
 * Full preview of a place contribution for Admin review.
 * Renders everything the user actually submitted (payload-driven,
 * no parallel data system), plus the map pin when coordinates exist.
 */
export function ContributionPreviewModal({
  contribution,
  onClose,
}: {
  contribution: ContributionRead
  onClose: () => void
}) {
  const payload = contribution.payload ?? {}
  const latitude = toNumberOrNull(payload.latitude)
  const longitude = toNumberOrNull(payload.longitude)
  const hasCoordinates = latitude !== null && longitude !== null

  const knownKeys = new Set<string>([...PLACE_FIELDS.map((f) => f.key), 'latitude', 'longitude', 'is_active'])
  const extraEntries = Object.entries(payload).filter(
    ([key, value]) => !knownKeys.has(key) && asString(value) !== null,
  )

  const listSummary = (key: string): string | null => {
    const value = payload[key]
    if (Array.isArray(value) && value.length > 0) return value.map(String).join('، ')
    return null
  }
  const workingHours = listSummary('working_hours') ?? listSummary('working_hours_json')
  const services = listSummary('services')
  const imageCount = Array.isArray(payload.images) ? payload.images.length : 0

  /** Any other payload key that looks like a social/social-link entry. */
  const socialEntries = Object.entries(payload).filter(
    ([key, value]) =>
      key !== 'image_url' &&
      URL_KEYS.has(key) === false &&
      typeof value === 'string' &&
      /^https?:\/\//i.test(value),
  )

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="modal-card contribution-preview">
        <div className="contribution-preview-header">
          <h4>معاينة المساهمة</h4>
          <button type="button" className="btn btn-ghost btn-sm" onClick={onClose}>إغلاق</button>
        </div>

        <div className="contribution-preview-meta">
          <span className="badge badge-amber">{TYPE_LABELS[contribution.type]}</span>
          <span className="badge badge-muted">{STATUS_LABELS[contribution.status]}</span>
          <span className="cell-muted" dir="ltr">{contribution.user_email ?? 'بدون بريد'}</span>
        </div>

        {contribution.status === 'APPROVED' && (
          <p className="contribution-preview-note">النقاط الممنوحة: <strong>+{contribution.points_awarded}</strong></p>
        )}
        {contribution.status === 'PENDING' && (
          <p className="contribution-preview-note cell-muted">لم تُمنح النقاط بعد — ستُحدد عند الاعتماد.</p>
        )}
        {contribution.status === 'REJECTED' && contribution.rejection_reason && (
          <p className="error-note">سبب الرفض: {contribution.rejection_reason}</p>
        )}

        <dl className="contribution-preview-fields">
          {PLACE_FIELDS.map(({ key, label }) => {
            const value = asString(payload[key])
            if (value === null) return null
            const url = URL_KEYS.has(key) ? imageUrl(value) : null
            return (
              <div key={key} className="contribution-preview-field">
                <dt>{label}</dt>
                <dd>
                  {url !== null ? (
                    key === 'image_url'
                      ? <img src={url} alt={label} className="contribution-preview-image" />
                      : <a href={url} target="_blank" rel="noreferrer" dir="ltr">{url}</a>
                  ) : value}
                </dd>
              </div>
            )
          })}

          {socialEntries.map(([key, value]) => (
            <div key={key} className="contribution-preview-field">
              <dt>{key}</dt>
              <dd><a href={imageUrl(asString(value))!} target="_blank" rel="noreferrer" dir="ltr">{imageUrl(asString(value))}</a></dd>
            </div>
          ))}

          {extraEntries.map(([key, value]) => (
            <div key={key} className="contribution-preview-field">
              <dt>{key}</dt>
              <dd dir="auto">{JSON.stringify(value)}</dd>
            </div>
          ))}

          {workingHours !== null && (
            <div className="contribution-preview-field">
              <dt>أوقات العمل</dt>
              <dd>{workingHours}</dd>
            </div>
          )}
          {services !== null && (
            <div className="contribution-preview-field">
              <dt>الخدمات</dt>
              <dd>{services}</dd>
            </div>
          )}
          {imageCount > 0 && (
            <div className="contribution-preview-field">
              <dt>صور إضافية</dt>
              <dd>{imageCount} صورة</dd>
            </div>
          )}
        </dl>

        {hasCoordinates ? (
          <>
            <p className="contribution-preview-note">موقع المكان كما حدده المستخدم:</p>
            <ContributionPreviewMap latitude={latitude!} longitude={longitude!} />
            <p className="contribution-preview-note" dir="ltr">{latitude!.toFixed(6)}, {longitude!.toFixed(6)}</p>
          </>
        ) : (
          <p className="contribution-preview-note cell-muted">لا توجد إحداثيات في هذه المساهمة.</p>
        )}
      </div>
    </div>
  )
}
