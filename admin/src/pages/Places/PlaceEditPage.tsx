import { useState, type FormEvent } from 'react'
import { AlertTriangle, ArrowRight, Loader2, Save } from 'lucide-react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { userFacingError } from '../../api/errors'
import { useCategories } from '../../hooks/useCategories'
import { useUpdatePlace } from '../../hooks/usePlaceMutations'
import {
  VERIFICATION_STATUSES,
  type PlaceRead,
  type PlaceUpdatePayload,
} from '../../types/place'
import './place-actions.css'

export function PlaceEditPage() {
  const location = useLocation()
  const navigate = useNavigate()
  const categoriesQuery = useCategories()
  const updateMutation = useUpdatePlace()

  const [place] = useState<PlaceRead | null>(
    (location.state?.place as PlaceRead | undefined) ?? null,
  )

  const [name, setName] = useState(place?.name ?? '')
  const [categoryName, setCategoryName] = useState(place?.category_name ?? '')
  const [categoryId, setCategoryId] = useState(place?.category_id ?? '')
  const [imageUrl, setImageUrl] = useState(place?.image_url ?? '')
  const [city, setCity] = useState(place?.city ?? '')
  const [address, setAddress] = useState(place?.address ?? '')
  const [phone, setPhone] = useState(place?.phone ?? '')
  const [website, setWebsite] = useState(place?.website ?? '')
  const [description, setDescription] = useState(place?.description ?? '')
  const [openingTime, setOpeningTime] = useState(place?.opening_time ?? '')
  const [closingTime, setClosingTime] = useState(place?.closing_time ?? '')
  const [rating, setRating] = useState(String(place?.rating ?? ''))
  const [latitude, setLatitude] = useState(place?.latitude != null ? String(place.latitude) : '')
  const [longitude, setLongitude] = useState(place?.longitude != null ? String(place.longitude) : '')
  const [verificationStatus, setVerificationStatus] = useState(place?.verification_status ?? '')
  const [isOpen, setIsOpen] = useState(place?.is_open ?? false)
  const [isActive, setIsActive] = useState(place?.is_active ?? true)
  const [ownerUserId, setOwnerUserId] = useState(place?.owner_user_id ?? '')

  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  if (!place) {
    return (
      <div className="state-panel card">
        <AlertTriangle size={30} />
        <h2>بيانات المكان غير متاحة</h2>
        <p>تعذّر تحميل بيانات هذا المكان. عد إلى صفحة الأماكن ثم افتح التعديل من صفحة التفاصيل.</p>
        <Link className="back-link" to="/places">
          <ArrowRight size={17} /> العودة إلى الأماكن
        </Link>
      </div>
    )
  }

  function validate(): boolean {
    const errors: Record<string, string> = {}
    if (!name.trim()) errors.name = 'الاسم مطلوب'
    if (!categoryName.trim()) errors.categoryName = 'اسم القسم مطلوب'
    if (!city.trim()) errors.city = 'المدينة مطلوبة'
    if (!imageUrl.trim()) errors.imageUrl = 'رابط الصورة مطلوب'
    else if (!isHttpUrl(imageUrl.trim())) errors.imageUrl = 'أدخل رابطًا صالحًا يبدأ بـ http(s)'
    if (rating !== '' && (Number.isNaN(Number(rating)) || Number(rating) < 0)) {
      errors.rating = 'التقييم يجب أن يكون رقمًا غير سالب'
    }
    setFieldErrors(errors)
    return Object.keys(errors).length === 0
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!place) return
    if (!validate()) return

    const payload: PlaceUpdatePayload = {
      name: name.trim(),
      category_name: categoryName.trim(),
      city: city.trim(),
      image_url: imageUrl.trim(),
      description: description || null,
      address: address || null,
      phone: phone || null,
      website: website || null,
      opening_time: openingTime || null,
      closing_time: closingTime || null,
      rating: rating === '' ? 0 : Number(rating),
      latitude: latitude === '' ? null : Number(latitude),
      longitude: longitude === '' ? null : Number(longitude),
      is_open: isOpen,
      is_active: isActive,
      verification_status: (verificationStatus as PlaceUpdatePayload['verification_status']) || null,
      owner_user_id: ownerUserId || null,
      category_id: categoryId || null,
    }

    updateMutation.mutate(
      { id: place.id, payload },
      {
        onSuccess: (updated) => {
          navigate(`/places/${place.id}`, { replace: true, state: { place: updated } })
        },
      },
    )
  }

  const categoryOptions = (categoriesQuery.data ?? []).filter((category) => category.is_active)
return (
    <div className="place-actions-page">
      <Link className="back-link" to={`/places/${place.id}`} state={{ place }}>
        <ArrowRight size={17} /> العودة إلى التفاصيل
      </Link>
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة المحتوى</p>
          <h2>تعديل المكان</h2>
          <p className="muted">حدّث بيانات «{place.name}» ثم اضغط حفظ.</p>
        </div>
      </header>

      <form className="edit-form" onSubmit={handleSubmit} noValidate>
        <div className="form-grid">
          <TextInput id="place-name" label="الاسم" value={name} onChange={setName} error={fieldErrors.name} full />
          <TextInput id="place-city" label="المدينة" value={city} onChange={setCity} error={fieldErrors.city} />
          <TextInput id="place-category-name" label="اسم القسم" value={categoryName} onChange={setCategoryName} error={fieldErrors.categoryName} />
          <div className="form-field">
            <label htmlFor="place-category">القسم (اختياري)</label>
            <select id="place-category" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
              <option value="">بدون قسم</option>
              {categoryOptions.map((c) => (
                <option key={c.id} value={c.id}>{c.name_ar || c.name_en}</option>
              ))}
            </select>
          </div>
          <TextInput id="place-image-url" label="رابط الصورة" value={imageUrl} onChange={setImageUrl} error={fieldErrors.imageUrl} />
          <TextInput id="place-phone" label="الهاتف" value={phone} onChange={setPhone} />
          <TextInput id="place-website" label="الموقع الإلكتروني" value={website} onChange={setWebsite} />
          <TextInput id="place-address" label="العنوان" value={address} onChange={setAddress} />
          <div className="form-field full">
            <label htmlFor="place-description">الوصف</label>
            <textarea id="place-description" value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>
          <TextInput id="place-opening" label="ساعة الفتح" value={openingTime} onChange={setOpeningTime} />
          <TextInput id="place-closing" label="ساعة الإغلاق" value={closingTime} onChange={setClosingTime} />
          <NumberInput id="place-rating" label="التقييم" value={rating} onChange={setRating} error={fieldErrors.rating} step="0.1" />
          <NumberInput id="place-lat" label="خط العرض" value={latitude} onChange={setLatitude} />
          <NumberInput id="place-lng" label="خط الطول" value={longitude} onChange={setLongitude} />
          <div className="form-field">
            <label htmlFor="place-verification">حالة التحقق</label>
            <select id="place-verification" value={verificationStatus} onChange={(e) => setVerificationStatus(e.target.value)}>
              <option value="">بدون تحديد</option>
              {VERIFICATION_STATUSES.map((status) => (
                <option key={status} value={status}>{status}</option>
              ))}
            </select>
          </div>
          <TextInput id="place-owner" label="معرّف المالك" value={ownerUserId} onChange={setOwnerUserId} />
          <div className="form-field">
            <label className="form-toggle">
              <input type="checkbox" checked={isOpen} onChange={(e) => setIsOpen(e.target.checked)} />
              المكان مفتوح
            </label>
          </div>
          <div className="form-field">
            <label className="form-toggle">
              <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
              المكان نشط
            </label>
          </div>
        </div>

        {updateMutation.isError && (
          <div className="mutation-error" role="alert">
            {userFacingError(updateMutation.error)}
          </div>
        )}

        <div className="form-actions">
          <Link className="ghost-button" to={`/places/${place.id}`} state={{ place }}>
            إلغاء
          </Link>
          <button type="submit" className="primary-button" disabled={updateMutation.isPending}>
            {updateMutation.isPending ? <Loader2 className="spin" size={17} /> : <Save size={17} />}
            {updateMutation.isPending ? 'جارٍ الحفظ…' : 'حفظ التغييرات'}
          </button>
        </div>
      </form>
    </div>
  )
}

function isHttpUrl(value: string) {
  return /^https?:\/\/\S+$/i.test(value)
}

function TextInput({
  id, label, value, onChange, error, full,
}: {
  id: string
  label: string
  value: string
  onChange: (v: string) => void
  error?: string
  full?: boolean
}) {
  return (
    <div className={`form-field${full ? ' full' : ''}`}>
      <label htmlFor={id}>{label}</label>
      <input id={id} value={value} onChange={(e) => onChange(e.target.value)} />
      {error && <span className="field-error">{error}</span>}
    </div>
  )
}

function NumberInput({
  id, label, value, onChange, error, step,
}: {
  id: string
  label: string
  value: string
  onChange: (v: string) => void
  error?: string
  step?: string
}) {
  return (
    <div className="form-field">
      <label htmlFor={id}>{label}</label>
      <input id={id} type="number" step={step} value={value} onChange={(e) => onChange(e.target.value)} />
      {error && <span className="field-error">{error}</span>}
    </div>
  )
}