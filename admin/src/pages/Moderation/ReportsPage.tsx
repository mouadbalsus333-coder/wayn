import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useReports, useReportStats } from '../../hooks/useModeration'
import type { ReportStatus } from '../../types/moderation'
import {
  REPORT_CATEGORY_LABELS,
  StatsRow,
  StatusBadge,
  formatDate,
} from './moderationShared'
import './moderation.css'

export function ReportsPage() {
  const [page, setPage] = useState(1)
  const [limit] = useState(20)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState<string | undefined>(undefined)
  const [status, setStatus] = useState<ReportStatus | undefined>(undefined)
  const [category, setCategory] = useState<string | undefined>(undefined)
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
    () => ({ page, limit, search, status, category, created_from: createdFrom, created_to: createdTo }),
    [page, limit, search, status, category, createdFrom, createdTo],
  )

  const { data, isPending, isFetching, isError, error, refetch } = useReports(params)
  const { data: stats } = useReportStats()

  const hasActiveFilters =
    search !== undefined || status !== undefined || category !== undefined ||
    createdFrom !== undefined || createdTo !== undefined

  const clearFilters = useCallback(() => {
    setSearchInput('')
    setStatus(undefined)
    setCategory(undefined)
    setCreatedFrom(undefined)
    setCreatedTo(undefined)
    setPage(1)
  }, [])

  return (
    <div className="moderation-page">
      <header className="moderation-header">
        <div>
          <h2>البلاغات</h2>
          <p className="muted">إدارة بلاغات المستخدمين عن المنشورات ومعالجتها.</p>
        </div>
      </header>

      <StatsRow stats={stats} />

      <div className="card moderation-filters">
        <label className="filter-field search-field">
          <Search size={16} aria-hidden />
          <input
            type="search"
            placeholder="بحث في نص البلاغ أو أسماء المستخدمين…"
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
          />
        </label>
        <label className="filter-field">
          <span className="filter-label">الحالة</span>
          <select
            value={status ?? ''}
            onChange={(event) => {
              setPage(1)
              setStatus(event.target.value === '' ? undefined : (event.target.value as ReportStatus))
            }}
          >
            <option value="">الكل</option>
            <option value="PENDING">جديدة</option>
            <option value="UNDER_REVIEW">قيد المراجعة</option>
            <option value="RESOLVED">تمت معالجتها</option>
            <option value="REJECTED">مرفوضة</option>
            <option value="CANCELLED">ملغاة</option>
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">التصنيف</span>
          <select
            value={category ?? ''}
            onChange={(event) => {
              setPage(1)
              setCategory(event.target.value === '' ? undefined : event.target.value)
            }}
          >
            <option value="">الكل</option>
            {Object.entries(REPORT_CATEGORY_LABELS).map(([value, label]) => (
              <option key={value} value={value}>{label}</option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">من تاريخ</span>
          <input
            type="date"
            value={createdFrom ?? ''}
            onChange={(event) => {
              setPage(1)
              setCreatedFrom(event.target.value === '' ? undefined : event.target.value)
            }}
          />
        </label>
        <label className="filter-field">
          <span className="filter-label">إلى تاريخ</span>
          <input
            type="date"
            value={createdTo ?? ''}
            onChange={(event) => {
              setPage(1)
              setCreatedTo(event.target.value === '' ? undefined : event.target.value)
            }}
          />
        </label>
        {hasActiveFilters && (
          <button type="button" className="btn btn-ghost" onClick={clearFilters}>
            مسح الفلاتر
          </button>
        )}
      </div>

      {isPending ? (
        <div className="card state-card">جارٍ تحميل البلاغات…</div>
      ) : isError ? (
        <div className="card state-card">
          <p>تعذر تحميل البلاغات.</p>
          <p className="error-note">{userFacingError(error)}</p>
          <button type="button" className="btn btn-ghost" onClick={() => refetch()}>
            إعادة المحاولة
          </button>
        </div>
      ) : !data?.items.length ? (
        <div className="card state-card">لا توجد بلاغات مطابقة.</div>
      ) : (
        <>
          <div className="card table-card">
            <div className="table-scroll">
              <table className="moderation-table">
                <thead>
                  <tr>
                    <th>رقم البلاغ</th>
                    <th>الحالة</th>
                    <th>المُبلِّغ</th>
                    <th>صاحب المنشور</th>
                    <th>التصنيف</th>
                    <th>نص البلاغ</th>
                    <th>تاريخ البلاغ</th>
                    <th>المنشور</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.map((report) => (
                    <tr key={report.id}>
                      <td className="mono">{report.id.slice(0, 8)}</td>
                      <td><StatusBadge status={report.status} /></td>
                      <td>{report.reporter_name ?? '—'}</td>
                      <td>{report.post_owner_name ?? '—'}</td>
                      <td>{REPORT_CATEGORY_LABELS[report.category] ?? report.category}</td>
                      <td className="comment-cell">{report.description}</td>
                      <td className="cell-muted">{formatDate(report.created_at)}</td>
                      <td>
                        <Link className="btn btn-ghost btn-sm" to={`/moderation/reports/${report.id}`}>
                          عرض التفاصيل
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div className="pagination">
            <span className="cell-muted">
              صفحة {data.page} من {data.pages || 1} · {data.total} بلاغ
              {isFetching ? ' · جارٍ التحديث…' : ''}
            </span>
            <div className="pagination-actions">
              <button type="button" className="btn btn-ghost" disabled={page <= 1} onClick={() => setPage((c) => c - 1)}>
                السابق
              </button>
              <button
                type="button"
                className="btn btn-ghost"
                disabled={page >= (data.pages || 1)}
                onClick={() => setPage((c) => c + 1)}
              >
                التالي
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
