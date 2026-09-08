import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Loader2, Plus } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useCategories } from '../../hooks/useCategories'
import { useCreatePlace } from '../../hooks/usePlaceMutations'
import { permissions } from '../../permissions/permissionNames'
import { RequirePermission } from '../../auth/RequirePermission'
import type { PlaceCreatePayload } from '../../types/place'
import './places.css'
import './place-actions.css'

/**
 * Create Place (`POST /api/v1/admin/places`, `places.write`).
 * Mirrors backend `PlaceCreate` exactly — required: name, city,
 * category_name, image_url. Everything else is optional.
 */
export function PlaceCreatePage() {
  return (
    <RequirePermission permission={permissions.placesWrite}>
      <PlaceCreateForm />
    </RequirePermission>
  )
}

function PlaceCreateForm() {
  const navigate = useNavigate()
  const createMutation = useCreatePlace()
  const categoriesQuery = useCategories()

  const [name, setName] = useState('')
  const [city, setCity] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [categoryName, setCategoryName] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [description, setDescription] = useState('')
  const [address, setAddress] = useState('')
  const [phone, setPhone] = useState('')
  const [website, setWebsite] = useState('')
  const [latitude, setLatitude] = useState('')
  const [longitude, setLongitude] = useState('')
  const [openingTime, setOpeningTime] = useState('')
  const [closingTime, setClosingTime] = useState('')
  const [images, setImages] = useState('')
  const [services, setServices] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [isOpen, setIsOpen] = useState(true)
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})

  const submit = () => {
    const errors: Record<string, string> = {}
    if (!name.trim()) errors.name = 'اسم المكان مطلوب'
    if (!city.trim()) errors.city = 'المدينة مطلوبة'
    if (!categoryName.trim()) errors.categoryName = 'اسم الفئة مطلوب'
    if (!imageUrl.trim()) errors.imageUrl = 'رابط الصورة مطلوب'
    setFieldErrors(errors)
    if (Object.keys(errors).length > 0) return

    const payload: PlaceCreatePayload = {
      name: name.trim(),
      city: city.trim(),
      category_id: categoryId || null,
      category_name: categoryName.trim(),
      image_url: imageUrl.trim(),
      is_active: isActive,
      is_open: isOpen,
      description: description.trim() || null,
      address: address.trim() || null,
      phone: phone.trim() || null,
      website: website.trim() || null,
      latitude: latitude.trim() === '' ? null : Number(latitude),
      longitude: longitude.trim() === '' ? null : Number(longitude),
      opening_time: openingTime.trim() || null,
      closing_time: closingTime.trim() || null,
      images: images.split(',').map((s) => s.trim()).filter(Boolean),
      services: services.split(',').map((s) => s.trim()).filter(Boolean),
    }
    createMutation.mutate(payload, {
      onSuccess: (created) => navigate(`/places/${created.id}`, { replace: true }),
    })
  }

  return (
    <div className="place-actions-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة الأماكن</p>
          <h2>إضافة مكان جديد</h2>
          <p className="muted">الحقول المطلوبة: الاسم، المدينة، اسم الفئة، ورابط الصورة.</p>
        </div>
      </header>

      {createMutation.isError && (
        <div className="mutation-error" role="alert">
          {userFacingError(createMutation.error, 'تعذر إنشاء المكان.')}
        </div>
      )}

      <div className="card form-card">
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="pl-name">الاسم *</label>
            <input id="pl-name" value={name} onChange={(e) => setName(e.target.value)} />
            {fieldErrors.name && <span className="field-error">{fieldErrors.name}</span>}
          </div>
          <div className="form-field">
            <label htmlFor="pl-city">المدينة *</label>
            <input id="pl-city" value={city} onChange={(e) => setCity(e.target.value)} />
            {fieldErrors.city && <span className="field-error">{fieldErrors.city}</span>}
          </div>
          <div className="form-field">
            <label htmlFor="pl-category">الفئة</label>
            <select
              id="pl-category"
              value={categoryId}
              onChange={(e) => {
                setCategoryId(e.target.value)
                const selected = categoriesQuery.data?.find((c) => c.id === e.target.value)
                if (selected) setCategoryName(selected.name_en ?? selected.name_ar)
              }}
            >
              <option value="">— بدون —</option>
              {categoriesQuery.data?.map((c) => (
                <option key={c.id} value={c.id}>{c.name_ar}</option>
              ))}
            </select>
          </div>
          <div className="form-field">
            <label htmlFor="pl-category-name">اسم الفئة (نص) *</label>
            <input id="pl-category-name" value={categoryName} onChange={(e) => setCategoryName(e.target.value)} />
            {fieldErrors.categoryName && <span className="field-error">{fieldErrors.categoryName}</span>}
          </div>
          <div className="form-field full">
            <label htmlFor="pl-image">رابط الصورة الرئيسية *</label>
            <input id="pl-image" dir="ltr" value={imageUrl} onChange={(e) => setImageUrl(e.target.value)} />
            {fieldErrors.imageUrl && <span className="field-error">{fieldErrors.imageUrl}</span>}
          </div>
          <div className="form-field full">
            <label htmlFor="pl-desc">الوصف</label>
            <textarea id="pl-desc" value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-address">العنوان</label>
            <input id="pl-address" value={address} onChange={(e) => setAddress(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-phone">الهاتف</label>
            <input id="pl-phone" dir="ltr" value={phone} onChange={(e) => setPhone(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-website">الموقع الإلكتروني</label>
            <input id="pl-website" dir="ltr" value={website} onChange={(e) => setWebsite(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-lat">خط العرض</label>
            <input id="pl-lat" dir="ltr" type="number" step="any" value={latitude} onChange={(e) => setLatitude(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-lng">خط الطول</label>
            <input id="pl-lng" dir="ltr" type="number" step="any" value={longitude} onChange={(e) => setLongitude(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-open">وقت الفتح (HH:MM)</label>
            <input id="pl-open" dir="ltr" placeholder="09:00" value={openingTime} onChange={(e) => setOpeningTime(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="pl-close">وقت الإغلاق (HH:MM)</label>
            <input id="pl-close" dir="ltr" placeholder="22:00" value={closingTime} onChange={(e) => setClosingTime(e.target.value)} />
          </div>
          <div className="form-field full">
            <label htmlFor="pl-images">روابط صور إضافية (مفصولة بفاصلة)</label>
            <input id="pl-images" dir="ltr" value={images} onChange={(e) => setImages(e.target.value)} />
          </div>
          <div className="form-field full">
            <label htmlFor="pl-services">الخدمات (مفصولة بفاصلة)</label>
            <input id="pl-services" value={services} onChange={(e) => setServices(e.target.value)} />
          </div>
          <div className="form-field">
            <label className="form-toggle">
              <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} />
              المكان نشط
            </label>
          </div>
          <div className="form-field">
            <label className="form-toggle">
              <input type="checkbox" checked={isOpen} onChange={(e) => setIsOpen(e.target.checked)} />
              المكان مفتوح الآن
            </label>
          </div>
        </div>

        <div className="modal-actions">
          <Link className="ghost-button" to="/places">إلغاء</Link>
          <button type="button" className="primary-button" disabled={createMutation.isPending} onClick={submit}>
            {createMutation.isPending ? <Loader2 className="spin" size={16} /> : <Plus size={16} />}
            {createMutation.isPending ? 'جارٍ الإنشاء…' : 'إنشاء المكان'}
          </button>
        </div>
      </div>
    </div>
  )
}
