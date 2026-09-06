import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, EyeOff, MessageSquareText, RotateCcw, Search, Star, TriangleAlert } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useReviews } from '../../hooks/useReviews'
import { useReviewVisibilityMutation } from '../../hooks/useReviewMutations'
import { useAuth } from '../../auth/useAuth'
import { permissions } from '../../permissions/permissionNames'
import type { AdminReview } from '../../types/review'
import './reviews.css'

const RATINGS = [1, 2, 3, 4, 5]

function formatDate(value: string): string {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return date.toLocaleDateString('ar', { year: 'numeric', month: 'short', day: 'numeric' })
}

export function ReviewsPage() {
  const { hasPermission } = useAuth()
  const canModerate = hasPermission(permissions.reviewsModerate)

  const [page, setPage] = useState(1)
  const [limit] = useState(20)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState<string | undefined>(undefined)
  const [rating, setRating] = useState<number | undefined>(undefined)
  const [isVisible, setIsVisible] = useState<boolean | undefined>(undefined)
  const [pendingReview, setPendingReview] = useState<{ review: AdminReview; next: boolean } | null>(null)

  // Debounced server-side search (same pattern as Places).
  useEffect(() => {
    const timer = window.setTimeout(() => {
      setPage(1)
      setSearch(searchInput.trim() === '' ? undefined : searchInput.trim())
    }, 350)
    return () => window.clearTimeout(timer)
  }, [searchInput])

  const params = useMemo(
    () => ({ page, limit, search, rating, is_visible: isVisible }),
    [page, limit, search, rating, isVisible],
  )

  const { data, isPending, isFetching, isError, error, refetch } = useReviews(params)

  const hasActiveFilters =
    search !== undefined || rating !== undefined || isVisible !== undefined

  const clearFilters = useCallback(() => {
    setSearchInput('')
    setRating(undefined)
    setIsVisible(undefined)
    setPage(1)
  }, [])

  return (
    <div className="reviews-page">
      <header className="reviews-header">
        <div>
          <h2>المراجعات</h2>
          <p className="muted">إدارة مراجعات الأماكن وإظهارها أو إخفائها عن التطبيق.</p>
        </div>
      </header>

      <div className="card reviews-filters">
        <label className="filter-field search-field">
          <Search size={16} aria-hidden />
          <input
            type="search"
            placeholder="بحث في نص المراجعة…"
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
          />
        </label>
        <label className="filter-field">
          <span className="filter-label">التقييم</span>
          <select
            value={rating === undefined ? '' : String(rating)}
            onChange={(event) => {
              setPage(1)
              setRating(event.target.value === '' ? undefined : Number(event.target.value))
            }}
          >
            <option value="">الكل</option>
            {RATINGS.map((value) => (
              <option key={value} value={value}>
                {value} نجوم
              </option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">الحالة</span>
          <select
            value={isVisible === undefined ? '' : isVisible ? 'visible' : 'hidden'}
            onChange={(event) => {
              setPage(1)
              const value = event.target.value
              setIsVisible(value === '' ? undefined : value === 'visible')
            }}
          >
            <option value="">الكل</option>
            <option value="visible">ظاهرة</option>
            <option value="hidden">مخفية</option>
          </select>
        </label>
        {hasActiveFilters && (
          <button type="button" className="btn btn-ghost" onClick={clearFilters}>
            <RotateCcw size={16} /> مسح الفلاتر
          </button>
        )}
      </div>

      {isPending ? (
        <div className="card state-card" aria-busy="true">
          <p>جارٍ تحميل المراجعات…</p>
        </div>
      ) : isError ? (
        <div className="card state-card" role="alert">
          <TriangleAlert size={24} aria-hidden />
          <p>{userFacingError(error, 'تعذر تحميل المراجعات.')}</p>
          <button type="button" className="btn btn-primary" onClick={() => void refetch()}>
            <RotateCcw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : !data || data.items.length === 0 ? (
        <div className="card state-card">
          <MessageSquareText size={24} aria-hidden />
          <p>{hasActiveFilters ? 'لا توجد مراجعات مطابقة للبحث/الفلاتر.' : 'لا توجد مراجعات بعد.'}</p>
        </div>
      ) : (
        <>
          <div className="card table-card">
            <div className="table-scroll">
              <table className="reviews-table">
                <thead>
                  <tr>
                    <th>المراجعة</th>
                    <th>التقييم</th>
                    <th>المستخدم</th>
                    <th>المكان</th>
                    <th>الحالة</th>
                    <th>التاريخ</th>
                    <th>إجراء</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.map((review) => (
                    <tr key={review.id}>
                      <td className="comment-cell">
                        {review.comment ? review.comment : <span className="cell-muted">بدون نص</span>}
                        {review.images.length > 0 && (
                          <span className="images-count">📷 {review.images.length}</span>
                        )}
                      </td>
                      <td>
                        <span className="rating-cell" aria-label={`تقييم ${review.rating} من 5`}>
                          <Star size={14} className="star" aria-hidden /> {review.rating}
                        </span>
                      </td>
                      <td className="mono cell-muted">{review.user_id}</td>
                      <td className="mono cell-muted">{review.place_id}</td>
                      <td>
                        {review.is_visible ? (
                          <span className="badge badge-visible">ظاهرة</span>
                        ) : (
                          <span className="badge badge-hidden">مخفية</span>
                        )}
                      </td>
                      <td className="cell-muted">{formatDate(review.created_at)}</td>
                      <td>
                        {canModerate ? (
                          <button
                            type="button"
                            className={review.is_visible ? 'btn btn-ghost btn-sm' : 'btn btn-primary btn-sm'}
                            onClick={() => setPendingReview({ review, next: !review.is_visible })}
                          >
                            {review.is_visible ? (
                              <>
                                <EyeOff size={14} /> إخفاء
                              </>
                            ) : (
                              <>
                                <Eye size={14} /> إظهار
                              </>
                            )}
                          </button>
                        ) : (
                          <span className="cell-muted">—</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="pagination">
            <span className="cell-muted">
              صفحة {data.page} من {data.pages || 1} · {data.total} مراجعة
              {isFetching ? ' · جارٍ التحديث…' : ''}
            </span>
            <div className="pagination-actions">
              <button
                type="button"
                className="btn btn-ghost"
                disabled={page <= 1}
                onClick={() => setPage((current) => current - 1)}
              >
                السابق
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                disabled={page >= (data.pages || 1)}
                onClick={() => setPage((current) => current + 1)}
              >
                التالي
              </button>
            </div>
          </div>
        </>
      )}

      {pendingReview && (
        <VisibilityConfirmModal
          review={pendingReview.review}
          next={pendingReview.next}
          onClose={() => setPendingReview(null)}
        />
      )}
    </div>
  )
}

/** Confirmation dialog; the actual PATCH happens only after explicit confirm. */
function VisibilityConfirmModal({
  review,
  next,
  onClose,
}: {
  review: AdminReview
  next: boolean
  onClose: () => void
}) {
  const mutation = useReviewVisibilityMutation()

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal-card">
        <h4>{next ? 'إظهار المراجعة' : 'إخفاء المراجعة'}</h4>
        <p className="modal-summary">
          {next
            ? 'ستصبح المراجعة ظاهرة للمستخدمين في التطبيق.'
            : 'ستُخفى المراجعة عن المستخدمين دون حذفها من قاعدة البيانات.'}
        </p>
        {mutation.isError && (
          <p className="error-note" role="alert">
            {userFacingError(mutation.error)}
          </p>
        )}
        <div className="modal-actions">
          <button
            type="button"
            className="btn btn-primary"
            disabled={mutation.isPending}
            onClick={() => mutation.mutate({ reviewId: review.id, isVisible: next }, { onSuccess: onClose })}
          >
            {mutation.isPending ? 'جارٍ التنفيذ…' : 'تأكيد'}
          </button>
          <button type="button" className="btn btn-ghost" disabled={mutation.isPending} onClick={onClose}>
            إلغاء
          </button>
        </div>
      </div>
    </div>
  )
}

