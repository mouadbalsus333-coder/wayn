import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Eye, FilterX, RotateCcw, Search, UsersRound } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { formatDate } from '../../lib/format'
import { useRegularUsers } from '../../hooks/useRegularUsers'
import {
  ACCOUNT_STATUS_LABELS,
  type AccountStatus,
  type RegularUserListParams,
  type RegularUserSortBy,
} from '../../types/regularUser'
import './regular-users.css'

const PAGE_SIZE = 20

const SORT_OPTIONS: { value: RegularUserSortBy; label: string }[] = [
  { value: 'created_at', label: 'تاريخ الإنشاء' },
  { value: 'last_login_at', label: 'آخر دخول' },
  { value: 'full_name', label: 'الاسم' },
  { value: 'username', label: 'اسم المستخدم' },
  { value: 'points', label: 'النقاط' },
]

export function RegularUsersPage() {
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const [accountStatus, setAccountStatus] = useState<'' | AccountStatus>('')
  const [activeFilter, setActiveFilter] = useState<'' | 'true' | 'false'>('')
  const [verifiedFilter, setVerifiedFilter] = useState<'' | 'true' | 'false'>('')
  const [sortBy, setSortBy] = useState<RegularUserSortBy>('created_at')
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc')
  const [page, setPage] = useState(1)

  // Debounced search: no request per keystroke.
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, 350)
    return () => clearTimeout(timer)
  }, [searchInput])

  const hasFilters =
    accountStatus !== '' || activeFilter !== '' || verifiedFilter !== '' || search !== ''

  const params = useMemo<RegularUserListParams>(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      account_status: accountStatus || undefined,
      is_active: activeFilter === '' ? undefined : activeFilter === 'true',
      is_verified: verifiedFilter === '' ? undefined : verifiedFilter === 'true',
      sort_by: sortBy,
      sort_order: sortOrder,
    }),
    [page, search, accountStatus, activeFilter, verifiedFilter, sortBy, sortOrder],
  )

  const { data, isPending, isError, error, refetch, isFetching } = useRegularUsers(params)
  const items = data?.items ?? []
  const totalPages = data?.pages ?? 0

  function clearFilters() {
    setSearchInput('')
    setSearch('')
    setAccountStatus('')
    setActiveFilter('')
    setVerifiedFilter('')
    setSortBy('created_at')
    setSortOrder('desc')
    setPage(1)
  }

  return (
    <div className="rusers-page">
      <header className="rusers-header">
        <div>
          <h2>المستخدمين</h2>
          <p className="muted">
            إدارة حسابات مستخدمي تطبيق WAYN: البحث، الفلترة، ومتابعة حالة الحسابات.
          </p>
        </div>
        {hasFilters && (
          <button type="button" className="btn btn-ghost" onClick={clearFilters}>
            <FilterX size={16} /> مسح الفلاتر
          </button>
        )}
      </header>
      <div className="card rusers-toolbar">
        <label className="search-field">
          <Search size={16} />
          <input
            type="search"
            placeholder="ابحث بالاسم أو البريد أو اسم المستخدم…"
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
          />
        </label>
        <label className="filter-field">
          <span className="filter-label">حالة الحساب</span>
          <select
            value={accountStatus}
            onChange={(event) => {
              setAccountStatus(event.target.value as '' | AccountStatus)
              setPage(1)
            }}
          >
            <option value="">الكل</option>
            {Object.entries(ACCOUNT_STATUS_LABELS).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">النشاط</span>
          <select
            value={activeFilter}
            onChange={(event) => {
              setActiveFilter(event.target.value as '' | 'true' | 'false')
              setPage(1)
            }}
          >
            <option value="">الكل</option>
            <option value="true">نشط</option>
            <option value="false">معطل</option>
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">التوثيق</span>
          <select
            value={verifiedFilter}
            onChange={(event) => {
              setVerifiedFilter(event.target.value as '' | 'true' | 'false')
              setPage(1)
            }}
          >
            <option value="">الكل</option>
            <option value="true">موثّق</option>
            <option value="false">غير موثّق</option>
          </select>
        </label>
      </div>

      <div className="card rusers-sortbar">
        <label className="filter-field">
          <span className="filter-label">ترتيب حسب</span>
          <select value={sortBy} onChange={(event) => setSortBy(event.target.value as RegularUserSortBy)}>
            {SORT_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <label className="filter-field">
          <span className="filter-label">الاتجاه</span>
          <select value={sortOrder} onChange={(event) => setSortOrder(event.target.value as 'asc' | 'desc')}>
            <option value="desc">تنازلي</option>
            <option value="asc">تصاعدي</option>
          </select>
        </label>
      </div>

      {isPending ? (
        <div className="card" aria-busy="true">
          {Array.from({ length: 6 }, (_, index) => (
            <div key={index} className="skeleton-row" />
          ))}
        </div>
      ) : isError ? (
        <div className="card state-card" role="alert">
          <RotateCcw size={24} aria-hidden />
          <p>{userFacingError(error)}</p>
          <button type="button" className="btn btn-primary" onClick={() => void refetch()}>
            <RotateCcw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : items.length === 0 ? (
        <div className="card state-card">
          <UsersRound size={28} aria-hidden />
          <p>{hasFilters ? 'لا توجد نتائج مطابقة للبحث أو الفلاتر.' : 'لا يوجد مستخدمون بعد.'}</p>
        </div>
      ) : (
          <>
            <div className="card rusers-table">
              <table>
                <thead>
                  <tr>
                    <th>المستخدم</th>
                    <th>البريد الإلكتروني</th>
                    <th>حالة الحساب</th>
                    <th>النشاط</th>
                    <th>موثّق</th>
                    <th>النقاط</th>
                    <th>آخر دخول</th>
                    <th>تفاصيل</th>
                  </tr>
                </thead>
                <tbody>
                  {items.map((user) => (
                    <tr key={user.id}>
                      <td>
                        <div className="ruser-name-info">
                          <Link to={`/regular-users/${user.id}`}>{user.full_name}</Link>
                          <span className="cell-muted">@{user.username}</span>
                        </div>
                      </td>
                      <td className="cell-muted">{user.email}</td>
                      <td>
                        <StatusBadge status={user.account_status} />
                      </td>
                      <td>
                        <span className={`badge ${user.is_active ? 'badge-active' : 'badge-inactive'}`}>
                          {user.is_active ? 'نشط' : 'معطل'}
                        </span>
                      </td>
                      <td>
                        <span className={`badge ${user.is_verified ? 'badge-verified' : 'badge-unverified'}`}>
                          {user.is_verified ? 'موثّق' : 'غير موثّق'}
                        </span>
                      </td>
                      <td>{user.points}</td>
                      <td className="cell-muted">{formatDate(user.last_login_at)}</td>
                      <td>
                        <Link
                          to={`/regular-users/${user.id}`}
                          className="btn btn-ghost"
                          aria-label={`تفاصيل ${user.full_name}`}
                        >
                          <Eye size={16} />
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="pagination-row">
              <span className="pagination-info">
                {isFetching ? 'جارٍ التحديث…' : `الإجمالي: ${data?.total ?? 0} مستخدم`}
              </span>
              <div className="pagination-controls">
                <button
                  type="button"
                  className="btn btn-ghost"
                  disabled={page <= 1}
                  onClick={() => setPage((current) => current - 1)}
                >
                  السابق
                </button>
                <span className="pagination-info">
                  صفحة {page} من {totalPages || 1}
                </span>
                <button
                  type="button"
                  className="btn btn-ghost"
                  disabled={page >= totalPages}
                  onClick={() => setPage((current) => current + 1)}
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

function StatusBadge({ status }: { status: AccountStatus }) {
  const badgeClass =
    status === 'ACTIVE'
      ? 'badge-active'
      : status === 'HIDDEN'
        ? 'badge-unverified'
        : status === 'SUSPENDED'
          ? 'badge-pending'
          : 'badge-rejected'
  return <span className={`badge ${badgeClass}`}>{ACCOUNT_STATUS_LABELS[status]}</span>
}

