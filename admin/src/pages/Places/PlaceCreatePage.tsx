import { useMemo, useRef, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { AlertTriangle, Loader2, MapPin, Plus, Save } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { createPlaceSocial } from '../../api/places'
import { useAuth } from '../../auth/useAuth'
import { RequirePermission } from '../../auth/RequirePermission'
import { permissions } from '../../permissions/permissionNames'
import { useCategories } from '../../hooks/useCategories'
import { useCreateCategoryMutation } from '../../hooks/useCategoryMutations'
import { useCreatePlace } from '../../hooks/usePlaceMutations'
import type { CategoryRead } from '../../types/category'
import {
  PLACE_SOCIAL_TYPES,
  WEEKDAYS,
  type DayHoursInterval,
  type PlaceCreatePayload,
  type PlaceSocialCreate,
  type PlaceSocialType,
  type WeekdayKey,
  type WorkingHoursJson,
} from '../../types/place'
import { LocationMapPicker } from './LocationMapPicker'
import './places.css'
import './place-actions.css'

const DAY_LABELS: Record<WeekdayKey, string> = {
  saturday: 'السبت',
  sunday: 'الأحد',
  monday: 'الاثنين',
  tuesday: 'الثلاثاء',
  wednesday: 'الأربعاء',
  thursday: 'الخميس',
  friday: 'الجمعة',
}

const SOCIAL_LABELS: Record<PlaceSocialType, string> = {
  FACEBOOK: 'فيسبوك',
  YOUTUBE: 'يوتيوب',
  WHATSAPP: 'واتساب',
  WEB: 'موقع ويب',
  TIKTOK: 'تيك توك',
  INSTAGRAM: 'انستغرام',
}

const DEFAULT_PLACE_IMAGE = ''

type DayMode = 'closed' | 'open24' | 'custom'
type DayState = { mode: DayMode; intervals: DayHoursInterval[] }
type SocialModalState = { step: 'pick' } | { step: 'value'; type: PlaceSocialType } | null

function emptyDayState(): DayState {
  return { mode: 'closed', intervals: [{ open: '', close: '' }] }
}

const WORKING_HOURS_RE = /^([01]\d|2[0-3]):[0-5]\d$/

function isHttpUrl(value: string) {
  return /^https?:\/\/\S+$/i.test(value)
}

function isWhatsappInput(value: string) {
  return /^\+?[0-9][0-9\s\-()]{4,}$/.test(value.trim())
}

function workingHoursFromState(state: Record<WeekdayKey, DayState>): WorkingHoursJson | null {
  const out: WorkingHoursJson = {}
  for (const day of WEEKDAYS) {
    const st = state[day]
    if (st.mode === 'open24') {
      out[day] = { type: 'open24' }
    } else if (st.mode === 'custom') {
      const intervals = st.intervals.filter((i) => i.open.trim() !== '' && i.close.trim() !== '')
      if (intervals.length > 0) out[day] = { type: 'regular', intervals }
    }
  }
  return Object.keys(out).length > 0 ? out : null
}

export function PlaceCreatePage() {
  return (
    <RequirePermission permission={permissions.placesWrite}>
      <PlaceCreateForm />
    </RequirePermission>
  )
}
function PlaceCreateForm() {
  const navigate = useNavigate()
  const { hasPermission } = useAuth()
  const createMutation = useCreatePlace()
  const categoriesQuery = useCategories()
  const canWriteCategories = hasPermission(permissions.categoriesWrite)

  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [description, setDescription] = useState('')
  const [city, setCity] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [categoryName, setCategoryName] = useState('')

  const [latitude, setLatitude] = useState<number | null>(null)
  const [longitude, setLongitude] = useState<number | null>(null)

  const [dayStates, setDayStates] = useState<Record<WeekdayKey, DayState>>(() => {
    const initial = {} as Record<WeekdayKey, DayState>
    for (const day of WEEKDAYS) initial[day] = emptyDayState()
    return initial
  })

  const [socials, setSocials] = useState<PlaceSocialCreate[]>([])
  const [socialModal, setSocialModal] = useState<SocialModalState>(null)
  const [socialDraft, setSocialDraft] = useState('')
  const [socialError, setSocialError] = useState('')
  const [catModalOpen, setCatModalOpen] = useState(false)

  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({})
  const [formError, setFormError] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const submittingRef = useRef(false)

  const categories = useMemo(
    () => (categoriesQuery.data ?? []).filter((c) => c.is_active),
    [categoriesQuery.data],
  )

  const updateDay = (day: WeekdayKey, updater: (st: DayState) => DayState) => {
    setDayStates((prev) => ({ ...prev, [day]: updater(prev[day]) }))
  }

  const updateInterval = (
    day: WeekdayKey,
    index: number,
    field: 'open' | 'close',
    value: string,
  ) => {
    updateDay(day, (st) => ({
      ...st,
      intervals: st.intervals.map((interval, i) => i === index ? { ...interval, [field]: value } : interval),
    }))
  }

  const selectCategory = (category: CategoryRead) => {
    setCategoryId(category.id)
    setCategoryName(category.name_ar || category.name_en || '')
  }

  const daytimeValidate = (): string | undefined => {
    for (const day of WEEKDAYS) {
      const st = dayStates[day]
      if (st.mode !== 'custom') continue
      for (const interval of st.intervals) {
        for (const time of [interval.open, interval.close]) {
          if (time.trim() !== '' && !WORKING_HOURS_RE.test(time.trim())) {
            return `وقت غير صالح في يوم ${DAY_LABELS[day]} — استخدم صيغة HH:MM`
          }
        }
      }
    }
    return undefined
  }

  const validateSocials = (): string | undefined => {
    for (const s of socials) {
      if (s.social_type === 'WHATSAPP') {
        if (!isWhatsappInput(s.value)) return 'رقم واتساب غير صالح'
      } else if (!isHttpUrl(s.value.trim())) {
        return `رابط ${SOCIAL_LABELS[s.social_type]} غير صالح`
      }
    }
    return undefined
  }

  const submit = async () => {
    if (submittingRef.current) return

    const errors: Record<string, string> = {}
    if (!name.trim()) errors.name = 'اسم المكان مطلوب'
    if (!city.trim()) errors.city = 'المدينة مطلوبة'
    if (!categoryId) errors.category = 'يرجى اختيار التصنيف'
    if (latitude == null || longitude == null) errors.location = 'يرجى تحديد الموقع على الخريطة'
    const hoursError = daytimeValidate()
    if (hoursError) errors.hours = hoursError
    const socialsError = validateSocials()
    if (socialsError) errors.socials = socialsError

    setFieldErrors(errors)
    setFormError('')
    if (Object.keys(errors).length > 0) return

    const payload: PlaceCreatePayload = {
      name: name.trim(),
      city: city.trim(),
      category_id: categoryId,
      category_name: categoryName.trim(),
      image_url: DEFAULT_PLACE_IMAGE,
      is_active: true,
      description: description.trim() || null,
      phone: phone.trim() || null,
      latitude,
      longitude,
      images: [],
      services: [],
      working_hours_json: workingHoursFromState(dayStates),
    }

    submittingRef.current = true
    setSubmitting(true)
    try {
      const created = await createMutation.mutateAsync(payload)
      for (const social of socials) {
        try {
          await createPlaceSocial(created.id, social)
        } catch {
          // A social failure must not lose the already-created place.
        }
      }
      navigate(`/places/${created.id}`, { replace: true, state: { place: created } })
    } catch (error) {
      setFormError(userFacingError(error, 'تعذر إنشاء المكان.'))
    } finally {
      submittingRef.current = false
      setSubmitting(false)
    }
  }

  const addSocial = () => {
    if (!socialModal || socialModal.step !== 'value') return
    const { type } = socialModal
    const value = socialDraft.trim()
    if (type === 'WHATSAPP') {
      if (!isWhatsappInput(value)) { setSocialError('أدخل رقم واتساب صالحًا'); return }
    } else if (!isHttpUrl(value)) {
      setSocialError('أدخل رابطًا صالحًا يبدأ بـ http(s)')
      return
    }
    setSocials((prev) => [...prev, { social_type: type, value }])
    setSocialModal(null)
    setSocialDraft('')
    setSocialError('')
  }

  const removeSocial = (type: PlaceSocialType) => {
    setSocials((prev) => prev.filter((s) => s.social_type !== type))
  }

  const isBusy = createMutation.isPending || submitting
  const addedTypes = new Set(socials.map((s) => s.social_type))
  return (
    <div className="place-actions-page">
      <Link className="back-link" to="/places">
        <span>←</span> العودة إلى الأماكن
      </Link>

      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة الأماكن</p>
          <h2>إضافة مكان</h2>
          <p className="muted">حدّد بيانات المكان وموقعه وساعات عمله ووسائل تواصله.</p>
        </div>
      </header>

      {formError && (
        <div className="mutation-error" role="alert">
          <AlertTriangle size={16} /> {formError}
        </div>
      )}

      <div className="card form-card">
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="pl-name">اسم المكان *</label>
            <input id="pl-name" value={name} onChange={(e) => setName(e.target.value)} />
            {fieldErrors.name && <span className="field-error">{fieldErrors.name}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="pl-phone">رقم الهاتف</label>
            <input id="pl-phone" dir="ltr" value={phone} onChange={(e) => setPhone(e.target.value)} />
          </div>

          <div className="form-field">
            <label htmlFor="pl-city">المدينة *</label>
            <input id="pl-city" value={city} onChange={(e) => setCity(e.target.value)} />
            {fieldErrors.city && <span className="field-error">{fieldErrors.city}</span>}
            <span className="field-hint">لا يستطيع النظام استنتاج المدينة من الإحداثيات فيُدخلها الأدمن يدويًا.</span>
          </div>

          <div className="form-field">
            <label htmlFor="pl-category">التصنيف *</label>
            <div className="category-input-row">
              <select
                id="pl-category"
                className="grow"
                value={categoryId}
                onChange={(e) => {
                  const selected = categories.find((c) => c.id === e.target.value)
                  if (selected) selectCategory(selected)
                  else { setCategoryId(''); setCategoryName('') }
                }}
              >
                <option value="">— اختر التصنيف —</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>{c.name_ar}</option>
                ))}
              </select>
              {canWriteCategories && (
                <button type="button" className="ghost-button" onClick={() => setCatModalOpen(true)}>
                  <Plus size={16} /> إضافة تصنيف
                </button>
              )}
            </div>
            {fieldErrors.category && <span className="field-error">{fieldErrors.category}</span>}
          </div>

          <div className="form-field full">
            <label htmlFor="pl-desc">الوصف</label>
            <textarea id="pl-desc" value={description} onChange={(e) => setDescription(e.target.value)} />
          </div>
        </div>

        <section className="form-section">
          <h3 className="form-section-title">
            <MapPin size={17} /> تحديد الموقع
          </h3>
          <p className="muted">اضغط على الخريطة لوضع العلامة أو اسحبها لتغيير الموقع.</p>
          <LocationMapPicker
            latitude={latitude}
            longitude={longitude}
            onSelect={(lat, lng) => { setLatitude(lat); setLongitude(lng) }}
          />
          {fieldErrors.location && <span className="field-error">{fieldErrors.location}</span>}
          {latitude != null && longitude != null && (
            <p className="coords-label" dir="ltr">
              {latitude.toFixed(6)}, {longitude.toFixed(6)}
            </p>
          )}
        </section>
        <section className="form-section">
          <h3 className="form-section-title">ساعات العمل</h3>
          <p className="muted">عيّن ساعات كل يوم؛ تُستخدم تلقائيًا لحساب مفتوح/مغلق الآن داخل Explore والخريطة.</p>
          {fieldErrors.hours && <span className="field-error">{fieldErrors.hours}</span>}
          <div className="hours-grid">
            {WEEKDAYS.map((day) => (
              <DayHoursEditor
                key={day}
                label={DAY_LABELS[day]}
                state={dayStates[day]}
                onChange={(updater) => updateDay(day, updater)}
                onIntervalChange={(index, field, value) => updateInterval(day, index, field, value)}
                onAddInterval={() =>
                  updateDay(day, (st) => ({ ...st, intervals: [...st.intervals, { open: '', close: '' }] }))
                }
                onRemoveInterval={(index) =>
                  updateDay(day, (st) => ({ ...st, intervals: st.intervals.filter((_, i) => i !== index) }))
                }
              />
            ))}
          </div>
        </section>

        <section className="form-section">
          <h3 className="form-section-title">وسائل التواصل</h3>
          <p className="muted">أضف وسائل تواصل للمكان. يخزَّن رقم واتساب كرقم فقط، ويُفتح رابط المحادثة تلقائيًا في التطبيق.</p>
          {fieldErrors.socials && <span className="field-error">{fieldErrors.socials}</span>}
          {socials.length > 0 && (
            <div className="social-chips">
              {socials.map((s) => (
                <span className="social-chip" key={s.social_type}>
                  {SOCIAL_LABELS[s.social_type]}
                  <span className="social-chip-value" dir="ltr">{s.value}</span>
                  <button
                    type="button"
                    className="chip-remove"
                    disabled={isBusy}
                    onClick={() => removeSocial(s.social_type)}
                    aria-label={`إزالة ${SOCIAL_LABELS[s.social_type]}`}
                  >
                    ✕
                  </button>
                </span>
              ))}
            </div>
          )}
          <button
            type="button"
            className="ghost-button"
            disabled={isBusy || socials.length >= PLACE_SOCIAL_TYPES.length}
            onClick={() => setSocialModal({ step: 'pick' })}
          >
            <Plus size={16} /> إضافة وسيلة تواصل
          </button>
        </section>

        <div className="modal-actions">
          <Link className="ghost-button" to="/places">إلغاء</Link>
          <button type="button" className="primary-button" disabled={isBusy} onClick={() => void submit()}>
            {isBusy ? <Loader2 className="spin" size={16} /> : <Save size={16} />}
            {isBusy ? 'جارٍ الحفظ…' : 'إضافة المكان'}
          </button>
        </div>
      </div>

      {catModalOpen && (
        <CategoryModal
          onClose={() => setCatModalOpen(false)}
          onCreated={(category) => {
            setCatModalOpen(false)
            selectCategory(category)
          }}
        />
      )}

      {socialModal && (
        <SocialModal
          state={socialModal}
          draft={socialDraft}
          error={socialError}
          addedTypes={addedTypes}
          onDraftChange={setSocialDraft}
          onPick={(type) => { setSocialModal({ step: 'value', type }); setSocialDraft(''); setSocialError('') }}
          onBack={() => setSocialModal({ step: 'pick' })}
          onAdd={addSocial}
          onClose={() => { setSocialModal(null); setSocialDraft(''); setSocialError('') }}
        />
      )}
    </div>
  )
}
// ---------------------------------------------------------------------------
// DayHoursEditor
// ---------------------------------------------------------------------------

function DayHoursEditor({
  label,
  state,
  onChange,
  onIntervalChange,
  onAddInterval,
  onRemoveInterval,
}: {
  label: string
  state: DayState
  onChange: (updater: (st: DayState) => DayState) => void
  onIntervalChange: (index: number, field: 'open' | 'close', value: string) => void
  onAddInterval: () => void
  onRemoveInterval: (index: number) => void
}) {
  const mode = state.mode
  return (
    <div className={`hours-day${mode === 'closed' ? ' is-closed' : ''}`}>
      <div className="hours-day-head">
        <span className="hours-day-name">{label}</span>
        <select
          className="hours-day-mode"
          value={mode}
          onChange={(e) => {
            const next = e.target.value as DayMode
            onChange((st) => ({
              ...st,
              mode: next,
              intervals: next === 'custom' && st.intervals.length === 0 ? [{ open: '', close: '' }] : st.intervals,
            }))
          }}
        >
          <option value="closed">مغلق</option>
          <option value="open24">24 ساعة</option>
          <option value="custom">ساعات محددة</option>
        </select>
      </div>

      {mode === 'open24' && <p className="hours-24-label">مفتوح طوال اليوم (24 ساعة)</p>}

      {mode === 'custom' && (
        <div className="hours-intervals">
          {state.intervals.map((interval, index) => (
            <div className="hours-interval-row" key={index}>
              <input
                type="time"
                className="hours-time"
                value={interval.open}
                onChange={(e) => onIntervalChange(index, 'open', e.target.value)}
                aria-label={`وقت فتح ${label}`}
              />
              <span className="hours-arrow">→</span>
              <input
                type="time"
                className="hours-time"
                value={interval.close}
                onChange={(e) => onIntervalChange(index, 'close', e.target.value)}
                aria-label={`وقت إغلاق ${label}`}
              />
              {state.intervals.length > 1 && (
                <button type="button" className="chip-remove" onClick={() => onRemoveInterval(index)}>
                  ✕
                </button>
              )}
            </div>
          ))}
          <button type="button" className="add-interval-button" onClick={onAddInterval}>
            <Plus size={13} /> إضافة فترة
          </button>
          <p className="field-hint">لتمديد ما بعد منتصف الليل اجعل وقت الإغلاق أصغر من الفتح (مثال 18:00 ← 01:00).</p>
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// CategoryModal
// ---------------------------------------------------------------------------

function CategoryModal({ onClose, onCreated }: { onClose: () => void; onCreated: (c: CategoryRead) => void }) {
  const createMutation = useCreateCategoryMutation()
  const [nameAr, setNameAr] = useState('')
  const [nameEn, setNameEn] = useState('')
  const [error, setError] = useState('')

  const save = () => {
    if (!nameAr.trim()) { setError('الاسم العربي مطلوب'); return }
    createMutation.mutate(
      { name_ar: nameAr.trim(), name_en: nameEn.trim() || null, is_active: true },
      {
        onSuccess: (category) => onCreated(category),
        onError: (err) => setError(userFacingError(err, 'تعذر إنشاء التصنيف.')),
      },
    )
  }

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="إضافة تصنيف">
      <div className="modal">
        <h3>إضافة تصنيف</h3>
        <p>أضف تصنيفًا جديدًا ليُستخدم مباشرة لهذا المكان.</p>
        <div className="form-grid">
          <div className="form-field">
            <label htmlFor="cat-ar">الاسم العربي *</label>
            <input id="cat-ar" value={nameAr} onChange={(e) => setNameAr(e.target.value)} />
          </div>
          <div className="form-field">
            <label htmlFor="cat-en">الاسم الإنجليزي</label>
            <input id="cat-en" value={nameEn} onChange={(e) => setNameEn(e.target.value)} />
          </div>
        </div>
        {error && <div className="mutation-error" role="alert">{error}</div>}
        <div className="modal-actions">
          <button type="button" className="ghost-button" disabled={createMutation.isPending} onClick={onClose}>إلغاء</button>
          <button type="button" className="primary-button" disabled={createMutation.isPending} onClick={save}>
            {createMutation.isPending ? <Loader2 className="spin" size={16} /> : <Plus size={16} />}
            {createMutation.isPending ? 'جارٍ الحفظ…' : 'إضافة'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// SocialModal
// ---------------------------------------------------------------------------

function SocialModal({
  state,
  draft,
  error,
  addedTypes,
  onDraftChange,
  onPick,
  onBack,
  onAdd,
  onClose,
}: {
  state: { step: 'pick' } | { step: 'value'; type: PlaceSocialType }
  draft: string
  error: string
  addedTypes: Set<PlaceSocialType>
  onDraftChange: (value: string) => void
  onPick: (type: PlaceSocialType) => void
  onBack: () => void
  onAdd: () => void
  onClose: () => void
}) {
  const available = PLACE_SOCIAL_TYPES.filter((t) => !addedTypes.has(t))

  return (
    <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label="إضافة وسيلة تواصل">
      <div className="modal">
        {state.step === 'pick' ? (
          <>
            <h3>إضافة وسيلة تواصل</h3>
            <p>اختر نوع وسيلة التواصل.</p>
            {available.length === 0 ? (
              <p className="muted">تمت إضافة جميع أنواع وسائل التواصل المتاحة.</p>
            ) : (
              <div className="social-type-list">
                {available.map((type) => (
                  <button key={type} type="button" className="social-type-row" onClick={() => onPick(type)}>
                    {SOCIAL_LABELS[type]}
                  </button>
                ))}
              </div>
            )}
            <div className="modal-actions">
              <button type="button" className="ghost-button" onClick={onClose}>إغلاق</button>
            </div>
          </>
        ) : (
          <>
            <h3>{SOCIAL_LABELS[state.type]}</h3>
            {state.type === 'WHATSAPP' ? (
              <>
                <p>أدخل رقم واتساب. يخزَّن الرقم فقط ويُنشأ رابط المحادثة تلقائيًا في التطبيق.</p>
                <div className="form-field">
                  <label htmlFor="whatsapp-number">رقم WhatsApp</label>
                  <input id="whatsapp-number" dir="ltr" placeholder="+218000000000" value={draft} onChange={(e) => onDraftChange(e.target.value)} />
                </div>
              </>
            ) : (
              <>
                <p>أدخل رابط {SOCIAL_LABELS[state.type]}.</p>
                <div className="form-field">
                  <label htmlFor="social-url">الرابط</label>
                  <input id="social-url" dir="ltr" placeholder="https://…" value={draft} onChange={(e) => onDraftChange(e.target.value)} />
                </div>
              </>
            )}
            {error && <div className="mutation-error" role="alert">{error}</div>}
            <div className="modal-actions">
              <button type="button" className="ghost-button" onClick={onBack}>رجوع</button>
              <button type="button" className="ghost-button" onClick={onClose}>إلغاء</button>
              <button type="button" className="primary-button" onClick={onAdd}>
                <Plus size={16} /> إضافة
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
