import { useState } from 'react'
import {
  AlertTriangle,
  ArrowRight,
  CheckCircle2,
  Clock,
  Edit,
  Eye,
  Globe,
  Loader2,
  MapPin,
  Phone,
  Star,
  Trash2,
  User,
  type LucideIcon,
} from 'lucide-react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { userFacingError } from '../../api/errors'
import { useAuth } from '../../auth/useAuth'
import { useDeletePlace } from '../../hooks/usePlaceMutations'
import { permissions } from '../../permissions/permissionNames'
import type { PlaceRead } from '../../types/place'
import './place-actions.css'

export function PlaceDetailsPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const { hasPermission } = useAuth()
  const deleteMutation = useDeletePlace()
  const [confirmOpen, setConfirmOpen] = useState(false)

  const place = (location.state?.place as PlaceRead | undefined) ?? null

  if (!place) {
    return (
      <div className="state-panel card">
        <AlertTriangle size={30} />
        <h2>بيانات المكان غير متاحة</h2>
        <p>تعذّر تحميل تفاصيل هذا المكان من القائمة. عد إلى صفحة الأماكن لعرضها.</p>
        <Link className="back-link" to="/places">
          <ArrowRight size={17} /> العودة إلى الأماكن
        </Link>
      </div>
    )
  }

  const canWrite = hasPermission(permissions.placesWrite)
  const canDelete = hasPermission(permissions.placesDelete)

  function handleDeleteConfirmed() {
    if (!place) return
    deleteMutation.mutate(place.id, {
      onSuccess: () => navigate('/places', { replace: true }),
    })
  }

  return (
    <div className="place-actions-page">
      <Link className="back-link" to="/places">
        <ArrowRight size={17} /> العودة إلى الأماكن
      </Link>

      <section className="place-hero-card">
        {place.image_url ? (
          <img className="place-hero-media" src={place.image_url} alt={place.name} />
        ) : (
          <span className="place-hero-media"><MapPin size={40} /></span>
        )}
        <div className="place-hero-main">
          <h2>{place.name}</h2>
          <div className="place-hero-meta">
            <span className={`badge ${place.is_active ? 'badge-verified' : 'badge-inactive'}`}>
              {place.is_active ? 'نشط' : 'غير نشط'}
            </span>
            <VerificationPill status={place.verification_status} />
            <span className="badge badge-neutral"><Star size={13} /> {place.rating?.toFixed(1)}</span>
          </div>
          {place.description && <p className="muted" style={{ margin: '12px 0 0' }}>{place.description}</p>}
          <div className="place-hero-actions">
            {canWrite && (
              <Link
                className="primary-button"
                to={`/places/${place.id}/edit`}
                state={{ place }}
              >
                <Edit size={17} /> تعديل
              </Link>
            )}
            {canDelete && (
              <button type="button" className="danger-button" onClick={() => setConfirmOpen(true)}>
                <Trash2 size={17} /> حذف
              </button>
            )}
          </div>
        </div>
      </section>

      <InfoGrid place={place} />

      {canDelete && (
        <section className="danger-zone">
          <h3>منطقة الخطر</h3>
          <p>حذف هذا المكان سيؤدي إلى إزالته نهائيًا من النظام مع البيانات المرتبطة به. لا يمكن التراجع.</p>
          <button type="button" className="danger-button" onClick={() => setConfirmOpen(true)}>
            <Trash2 size={17} /> حذف المكان نهائيًا
          </button>
        </section>
      )}

      {deleteMutation.isError && (
        <div className="mutation-error" role="alert">
          {userFacingError(deleteMutation.error)}
        </div>
      )}

      {confirmOpen && (
        <ConfirmDelete
          placeName={place.name}
          deleting={deleteMutation.isPending}
          onCancel={() => setConfirmOpen(false)}
          onConfirm={handleDeleteConfirmed}
        />
      )}
    </div>
  )
}
function VerificationPill({ status }: { status?: string | null }) {
  if (!status) return <span className="badge badge-neutral">غير محدد</span>
  const variant = status === 'VERIFIED' ? 'verified' : status === 'PENDING' ? 'pending' : status === 'REJECTED' ? 'rejected' : 'unverified'
  return <span className={`badge badge-${variant}`}>{status}</span>
}

function InfoRow({ icon: Icon, label, value }: { icon: LucideIcon; label: string; value?: string | null }) {
  return (
    <div className="info-row">
      <Icon size={17} className="info-icon" />
      <strong>{label}:</strong>
      <span>{value || '—'}</span>
    </div>
  )
}

function InfoGrid({ place }: { place: PlaceRead }) {
  const locationText =
    place.latitude != null && place.longitude != null
      ? `${place.latitude.toFixed(5)}, ${place.longitude.toFixed(5)}`
      : null

  return (
    <>
      <div className="info-grid">
        <div className="info-card">
          <h3>المعلومات الأساسية</h3>
          <InfoRow icon={MapPin} label="المدينة" value={place.city} />
          <InfoRow icon={MapPin} label="العنوان" value={place.address} />
          <InfoRow icon={MapPin} label="القسم" value={place.category_name} />
          <InfoRow icon={Phone} label="الهاتف" value={place.phone} />
          <InfoRow icon={Globe} label="الموقع" value={place.website} />
        </div>

        <div className="info-card">
          <h3>الإحصائيات</h3>
          <InfoRow icon={Star} label="التقييم" value={place.rating?.toFixed(1)} />
          <InfoRow icon={Eye} label="عدد المراجعات" value={String(place.reviews_count)} />
          <InfoRow icon={Eye} label="عدد الزيارات" value={String(place.visits_count)} />
          <InfoRow icon={Clock} label="ساعات العمل" value={hoursLabel(place)} />
        </div>

        <div className="info-card">
          <h3>الموقع والتحقق</h3>
          <InfoRow icon={MapPin} label="الإحداثيات" value={locationText} />
          <InfoRow icon={User} label="المالك" value={place.owner_user_id ?? undefined} />
          <InfoRow icon={CheckCircle2} label="حالة الفتح" value={place.is_open ? 'مفتوح' : 'مغلق'} />
        </div>
      </div>

      {Array.isArray(place.services) && place.services.length > 0 && (
        <div className="info-card" style={{ marginBottom: 22 }}>
          <h3>الخدمات</h3>
          <div className="services-list">
            {place.services.map((service) => (
              <span className="service-chip" key={service}>{service}</span>
            ))}
          </div>
        </div>
      )}
    </>
  )
}

function hoursLabel(place: PlaceRead) {
  if (place.opening_time && place.closing_time) {
    return `${place.opening_time} — ${place.closing_time}`
  }
  return undefined
}

function ConfirmDelete({
  placeName,
  deleting,
  onCancel,
  onConfirm,
}: {
  placeName: string
  deleting: boolean
  onCancel: () => void
  onConfirm: () => void
}) {
  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="تأكيد الحذف">
      <div className="modal">
        <h3>حذف المكان</h3>
        <p>
          هل أنت متأكد من حذف «{placeName}»؟ هذه العملية <strong>نهائية</strong> ولا يمكن التراجع عنها،
          وستؤدي إلى إزالة المكان والبيانات المرتبطة به من النظام.
        </p>
        <div className="modal-actions">
          <button type="button" className="ghost-button" onClick={onCancel} disabled={deleting}>
            إلغاء
          </button>
          <button type="button" className="danger-button" onClick={onConfirm} disabled={deleting}>
            {deleting ? <Loader2 className="spin" size={17} /> : <Trash2 size={17} />}
            {deleting ? 'جارٍ الحذف…' : 'نعم، احذف نهائيًا'}
          </button>
        </div>
      </div>
    </div>
  )
}