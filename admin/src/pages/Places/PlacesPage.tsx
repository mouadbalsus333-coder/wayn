import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  AlertTriangle,
  ChevronLeft,
  ChevronRight,
  Eye,
  Loader2,
  MapPin,
  RefreshCw,
  Search,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useCategories } from '../../hooks/useCategories'
import { usePlaces } from '../../hooks/usePlaces'
import {
  VERIFICATION_STATUSES,
  type AdminPlaceListParams,
  type PlaceRead,
  type PlaceSortBy,
  type SortOrder,
  type VerificationStatus,
} from '../../types/place'
import './places.css'

const PAGE_SIZE = 20

function formatRating(value: number) {
  if (value == null) return '—'
  return `${value.toFixed(1)}`
}

function EmptyCell() {
  return <span className="cell-muted">—</span>
}

function VerificationBadge({ status }: { status?: VerificationStatus | null }) {
  if (!status) return <EmptyCell />
  const variant = status === 'VERIFIED' ? 'verified' : status === 'PENDING' ? 'pending' : status === 'REJECTED' ? 'rejected' : 'unverified'
  return <span className={`badge badge-${variant}`}>{status}</span>
}

export function PlacesPage() {
  const [page, setPage] = useState(1)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const [categoryId, setCategoryId] = useState('')
  const [verificationStatus, setVerificationStatus] = useState('')
  const [isActive, setIsActive] = useState('')
  const [sortBy, setSortBy] = useState<PlaceSortBy>('created_at')
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc')
// Debounce the search input so we don't fire a request per keystroke.
  useEffect(() => {
    const timeout = window.setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, 350)
    return () => window.clearTimeout(timeout)
  }, [searchInput])

  // Changing any filter resets pagination to the first page.
  const params: AdminPlaceListParams = {
    page,
    limit: PAGE_SIZE,
    search: search || null,
    category_id: categoryId || null,
    verification_status: (verificationStatus as VerificationStatus | '') || null,
    is_active: isActive === '' ? null : isActive === 'true',
    sort_by: sortBy,
    sort_order: sortOrder,
  }

  const { data, isPending, isError, error, refetch } = usePlaces(params)
  const categoriesQuery = useCategories()

  function resetFilters() {
    setSearchInput('')
    setSearch('')
    setCategoryId('')
    setVerificationStatus('')
    setIsActive('')
    setSortBy('created_at')
    setSortOrder('desc')
    setPage(1)
  }

  const totalPages = Math.max(1, data?.pages ?? 0)
  const hasFilters =
    search !== '' || categoryId !== '' || verificationStatus !== '' || isActive !== ''

  const categoryOptions = useMemo(() => {
    const options = categoriesQuery.data ?? []
    return options.filter((category) => category.is_active)
  }, [categoriesQuery.data])
return (
    <div className="places-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة المحتوى</p>
          <h2>الأماكن</h2>
          <p className="muted">تصفح وابحث وصنّف الأماكن في النظام وفق صلاحياتك.</p>
        </div>
        {hasFilters && (
          <button type="button" className="ghost-button" onClick={resetFilters}>
            مسح الفلاتر
          </button>
        )}
      </header>

      <div className="places-toolbar">
        <label className="search-field">
          <Search size={17} />
          <input
            type="search"
            placeholder="ابحث عن اسم، مدينة، قسم، وصف أو عنوان…"
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
          />
        </label>
        <label className="filter-field">
          <span className="filter-label">القسم</span>
          <select value={categoryId} onChange={(event) => { setCategoryId(event.target.value); setPage(1) }}>
            <option value="">الكل</option>
            {categoryOptions.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name_ar || category.name_en}
              </option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">حالة التحقق</span>
          <select value={verificationStatus} onChange={(event) => { setVerificationStatus(event.target.value); setPage(1) }}>
            <option value="">الكل</option>
            {VERIFICATION_STATUSES.map((status) => (
              <option key={status} value={status}>{status}</option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">النشاط</span>
          <select value={isActive} onChange={(event) => { setIsActive(event.target.value); setPage(1) }}>
            <option value="">الكل</option>
            <option value="true">نشط</option>
            <option value="false">غير نشط</option>
          </select>
        </label>
      </div>

      <div className="places-toolbar places-sortbar">
        <label className="filter-field">
          <span className="filter-label">الترتيب حسب</span>
          <select value={sortBy} onChange={(event) => { setSortBy(event.target.value as PlaceSortBy); setPage(1) }}>
            <option value="created_at">تاريخ الإنشاء</option>
            <option value="updated_at">تاريخ التحديث</option>
            <option value="name">الاسم</option>
            <option value="rating">التقييم</option>
            <option value="reviews_count">عدد التقييمات</option>
            <option value="visits_count">عدد الزيارات</option>
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">الاتجاه</span>
          <select value={sortOrder} onChange={(event) => { setSortOrder(event.target.value as SortOrder); setPage(1) }}>
            <option value="desc">تنازلي</option>
            <option value="asc">تصاعدي</option>
          </select>
        </label>
      </div>
{isPending && (
        <div className="places-table card">
          <div className="skeleton-row" />
          <div className="skeleton-row" />
          <div className="skeleton-row" />
          <div className="skeleton-row" />
        </div>
      )}

      {isError && (
        <div className="state-panel state-error card">
          <AlertTriangle size={30} />
          <h2>تعذّر تحميل الأماكن</h2>
          <p>{userFacingError(error)}</p>
          <button type="button" className="primary-button" onClick={() => refetch()}>
            <RefreshCw size={17} />
            إعادة المحاولة
          </button>
        </div>
      )}

      {!isPending && !isError && data && data.items.length === 0 && (
        <div className="state-panel card">
          <MapPin size={30} />
          <h2>{hasFilters ? 'لا توجد نتائج مطابقة' : 'لا توجد أماكن بعد'}</h2>
          <p>
            {hasFilters
              ? 'جرّب تعديل أو مسح الفلاتر للعثور على ما تبحث عنه.'
              : 'لم تتم إضافة أي أماكن إلى النظام بعد.'}
          </p>
          {hasFilters && (
            <button type="button" className="ghost-button" onClick={resetFilters}>
              مسح الفلاتر
            </button>
          )}
        </div>
      )}

      {!isPending && !isError && data && data.items.length > 0 && (
        <>
          <div className="places-table card">
            <table>
              <thead>
                <tr>
                  <th>المكان</th>
                  <th>القسم</th>
                  <th>المدينة</th>
                  <th>التقييم</th>
                  <th>التحقق</th>
                  <th>الحالة</th>
                  <th>المراجعات</th>
                  <th>الإجراء</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((place: PlaceRead) => (
                  <tr key={place.id}>
                    <td>
                      <div className="place-name-cell">
                        {place.image_url ? (
                          <img className="place-thumb" src={place.image_url} alt="" loading="lazy" />
                        ) : (
                          <span className="place-thumb place-thumb-empty"><MapPin size={16} /></span>
                        )}
                        <div className="place-name-info">
                          <Link to={`/places/${place.id}`} state={{ place }}>
                            {place.name}
                          </Link>
                          {place.address ? <span className="cell-muted">{place.address}</span> : null}
                        </div>
                      </div>
                    </td>
                    <td>{place.category_name || <EmptyCell />}</td>
                    <td>{place.city || <EmptyCell />}</td>
                    <td>
                      <span className="rating-cell">★ {formatRating(place.rating)}</span>
                    </td>
                    <td><VerificationBadge status={place.verification_status} /></td>
                    <td>
                      {place.is_active ? (
                        <span className="badge badge-active">نشط</span>
                      ) : (
                        <span className="badge badge-inactive">غير نشط</span>
                      )}
                    </td>
                    <td>{place.reviews_count}</td>
                    <td>
                      <Link
                        className="ghost-button icon-button"
                        to={`/places/${place.id}`}
                        state={{ place }}
                        aria-label={`تفاصيل ${place.name}`}
                      >
                        <Eye size={17} />
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="pagination-row">
            <span className="pagination-info">
              {data.total} من النتائج — صفحة {data.page} من {Math.max(data.pages, 1)}
            </span>
            <div className="pagination-controls">
              <button
                type="button"
                className="ghost-button icon-button"
                disabled={page <= 1}
                onClick={() => setPage((current) => current - 1)}
                aria-label="الصفحة السابقة"
              >
                <ChevronRight size={17} />
              </button>
              <button
                type="button"
                className="ghost-button icon-button"
                disabled={page >= totalPages}
                onClick={() => setPage((current) => current + 1)}
                aria-label="الصفحة التالية"
              >
                <ChevronLeft size={17} />
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  )
}

export function PlacesLoadingFallback() {
  return (
    <div className="state-panel">
      <Loader2 className="spin" size={28} />
      <p>جارٍ التحقق من الصلاحيات…</p>
    </div>
  )
}