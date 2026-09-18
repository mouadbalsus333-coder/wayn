import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  FileText,
  Search,
  UserRound,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAppeals, useAppealStats } from '../../hooks/useModeration'
import type { AppealStatus } from '../../types/moderation'
import {
  APPEAL_STATUS_LABELS,
  APPEAL_TYPE_LABELS,
  StatsRow,
  StatusBadge,
  formatDate,
} from './moderationShared'
import './moderation.css'

export function AppealsPage() {
  const [page, setPage] = useState(1)
  const [limit] = useState(20)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState<string | undefined>(undefined)
  const [status, setStatus] = useState<AppealStatus | undefined>(undefined)
  const [type, setType] = useState<string | undefined>(undefined)
  const [createdFrom, setCreatedFrom] = useState<string | undefined>(undefined)
  const [createdTo, setCreatedTo] = useState<string | undefined>(undefined)

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setPage(1)
      setSearch(searchInput.trim() === '' ? undefined : searchInput.trim())
    }, 350)

    return () => window.clearTimeout(timer)
  }, [searchInput])

  const params = useMemo(
    () => ({
      page,
      limit,
      search,
      status,
      type,
      created_from: createdFrom,
      created_to: createdTo,
    }),
    [page, limit, search, status, type, createdFrom, createdTo],
  )

  const { data, isPending, isFetching, isError, error, refetch } = useAppeals(params)
  const { data: stats } = useAppealStats()

  const hasActiveFilters =
    search !== undefined ||
    status !== undefined ||
    type !== undefined ||
    createdFrom !== undefined ||
    createdTo !== undefined

  const clearFilters = useCallback(() => {
    setSearchInput('')
    setSearch(undefined)
    setStatus(undefined)
    setType(undefined)
    setCreatedFrom(undefined)
    setCreatedTo(undefined)
    setPage(1)
  }, [])

  return (
    <div className="moderation-page appeals-page">
      <header className="moderation-header">
        <div>
          <div className="moderation-eyebrow">إدارة المحتوى</div>
          <h2>الطعون</h2>
          <p className="muted">
            مراجعة طعون المستخدمين على تقييمات المنشورات واتخاذ الإجراء المناسب.
          </p>
        </div>
      </header>

      <section className="moderation-stats-section">
        <StatsRow stats={stats} />
      </section>

      <section className="card moderation-filters appeals-filters">
        <div className="filters-heading">
          <div>
            <h3>تصفية الطعون</h3>
            <span>ابحث وفلتر الطعون للوصول إلى الحالة المطلوبة بسرعة.</span>
          </div>

          {hasActiveFilters && (
            <button type="button" className="btn btn-ghost btn-sm" onClick={clearFilters}>
              مسح الفلاتر
            </button>
          )}
        </div>

        <div className="filters-grid">
          <label className="filter-field search-field">
            <span className="filter-label">البحث</span>
            <div className="filter-input-with-icon">
              <Search size={17} aria-hidden />
              <input
                type="search"
                placeholder="ابحث في سبب الطعن أو أسماء المستخدمين…"
                value={searchInput}
                onChange={(event) => setSearchInput(event.target.value)}
              />
            </div>
          </label>

          <label className="filter-field">
            <span className="filter-label">الحالة</span>
            <select
              value={status ?? ''}
              onChange={(event) => {
                setPage(1)
                setStatus(
                  event.target.value === ''
                    ? undefined
                    : (event.target.value as AppealStatus),
                )
              }}
            >
              <option value="">كل الحالات</option>
              {Object.entries(APPEAL_STATUS_LABELS).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>

          <label className="filter-field">
            <span className="filter-label">نوع الطعن</span>
            <select
              value={type ?? ''}
              onChange={(event) => {
                setPage(1)
                setType(event.target.value === '' ? undefined : event.target.value)
              }}
            >
              <option value="">كل الأنواع</option>
              {Object.entries(APPEAL_TYPE_LABELS).map(([value, label]) => (
                <option key={value} value={label}>
                  {label}
                </option>
              ))}
            </select>
          </label>

          <label className="filter-field">
            <span className="filter-label">من تاريخ</span>
            <div className="filter-input-with-icon">
              <CalendarDays size={16} aria-hidden />
              <input
                type="date"
                value={createdFrom ?? ''}
                onChange={(event) => {
                  setPage(1)
                  setCreatedFrom(
                    event.target.value === '' ? undefined : event.target.value,
                  )
                }}
              />
            </div>
          </label>

          <label className="filter-field">
            <span className="filter-label">إلى تاريخ</span>
            <div className="filter-input-with-icon">
              <CalendarDays size={16} aria-hidden />
              <input
                type="date"
                value={createdTo ?? ''}
                onChange={(event) => {
                  setPage(1)
                  setCreatedTo(
                    event.target.value === '' ? undefined : event.target.value,
                  )
                }}
              />
            </div>
          </label>
        </div>
      </section>

      {isPending ? (
        <div className="card state-card">
          <p>جارٍ تحميل الطعون…</p>
        </div>
      ) : isError ? (
        <div className="card state-card">
          <p>تعذر تحميل الطعون.</p>
          <p className="error-note">{userFacingError(error)}</p>
          <button type="button" className="btn btn-ghost" onClick={() => refetch()}>
            إعادة المحاولة
          </button>
        </div>
      ) : !data?.items.length ? (
        <div className="card state-card">
          <FileText size={30} aria-hidden />
          <strong>لا توجد طعون مطابقة</strong>
          <span className="cell-muted">
            جرّب تغيير الفلاتر أو البحث باستخدام كلمة أخرى.
          </span>
        </div>
      ) : (
        <>
          <section className="appeals-list-section">
            <div className="appeals-list-header">
              <div>
                <h3>قائمة الطعون</h3>
                <span>
                  {data.total} طعن
                  {isFetching ? ' · جارٍ التحديث…' : ''}
                </span>
              </div>
            </div>

            <div className="appeals-list">
              {data.items.map((appeal) => (
                <article className="card appeal-card" key={appeal.id}>
                  <div className="appeal-card-main">
                    <div className="appeal-card-top">
                      <div className="appeal-title-group">
                        <span className="appeal-id mono">
                          #{appeal.id.slice(0, 8)}
                        </span>
                        <StatusBadge status={appeal.status} />
                      </div>

                      <span className="appeal-date cell-muted">
                        <CalendarDays size={15} aria-hidden />
                        {formatDate(appeal.created_at)}
                      </span>
                    </div>

                    <div className="appeal-card-grid">
                      <div className="appeal-meta">
                        <span className="appeal-meta-label">الطاعن</span>
                        <div className="appeal-meta-value">
                          <UserRound size={16} aria-hidden />
                          <span>{appeal.complainant_name ?? 'غير معروف'}</span>
                        </div>
                      </div>

                      <div className="appeal-meta">
                        <span className="appeal-meta-label">صاحب المنشور</span>
                        <div className="appeal-meta-value">
                          <UserRound size={16} aria-hidden />
                          <span>{appeal.post_owner_name ?? 'غير معروف'}</span>
                        </div>
                      </div>

                      <div className="appeal-meta">
                        <span className="appeal-meta-label">نوع الطعن</span>
                        <div className="appeal-meta-value">
                          <span>
                            {APPEAL_TYPE_LABELS[appeal.type] ?? appeal.type}
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="appeal-reason">
                      <span className="appeal-meta-label">سبب الطعن</span>
                      <p>{appeal.reason}</p>
                    </div>
                  </div>

                  <div className="appeal-card-action">
                    <Link
                      className="btn btn-primary"
                      to={`/moderation/appeals/${appeal.id}`}
                    >
                      عرض التفاصيل
                      <ChevronLeft size={17} aria-hidden />
                    </Link>
                  </div>
                </article>
              ))}
            </div>
          </section>

          <div className="pagination">
            <span className="cell-muted">
              صفحة {data.page} من {data.pages || 1} · {data.total} طعن
            </span>

            <div className="pagination-actions">
              <button
                type="button"
                className="btn btn-ghost"
                disabled={page <= 1}
                onClick={() => setPage((current) => current - 1)}
              >
                <ChevronRight size={17} aria-hidden />
                السابق
              </button>

              <button
                type="button"
                className="btn btn-ghost"
                disabled={page >= (data.pages || 1)}
                onClick={() => setPage((current) => current + 1)}
              >
                التالي
                <ChevronLeft size={17} aria-hidden />
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  )
}