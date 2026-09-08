import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ChevronLeft, ChevronRight, Eye, Loader2, RefreshCw, Search, ShieldCheck, UserPlus } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAdminUsers } from '../../hooks/useAdminUsers'
import type { AdminUserListParams, AdminUserRead } from '../../types/adminUser'
import './admin-users.css'

const PAGE_SIZE = 20

export function AdminUsersPage() {
  const [page, setPage] = useState(1)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const [roleInput, setRoleInput] = useState('')
  const [role, setRole] = useState('')
  const [isActive, setIsActive] = useState('')

  // Debounce the search/role inputs so we don't fire a request per keystroke.
  useEffect(() => {
    const timeout = window.setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, 350)
    return () => window.clearTimeout(timeout)
  }, [searchInput])

  useEffect(() => {
    const timeout = window.setTimeout(() => {
      setRole(roleInput)
      setPage(1)
    }, 350)
    return () => window.clearTimeout(timeout)
  }, [roleInput])

  const params: AdminUserListParams = {
    page,
    limit: PAGE_SIZE,
    search: search || null,
    role: role || null,
    is_active: isActive === '' ? null : isActive === 'true',
  }

  const { data, isPending, isError, error, refetch, isFetching } = useAdminUsers(params)

  function resetFilters() {
    setSearchInput('')
    setSearch('')
    setRoleInput('')
    setRole('')
    setIsActive('')
    setPage(1)
  }

  const totalPages = Math.max(1, data?.pages ?? 0)
  const hasFilters = search !== '' || role !== '' || isActive !== ''

  return (
    <div className="users-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">إدارة النظام</p>
          <h2>المشرفين</h2>
          <p className="muted">حسابات فريق الإدارة وأدوارهم وصلاحياتهم. متاحة لـ Super Admin فقط.</p>
        </div>
        <Link to="/users/new" className="primary-button">
          <UserPlus size={16} /> مشرف جديد
        </Link>
        {hasFilters && (
          <button type="button" className="ghost-button" onClick={resetFilters}>
            مسح الفلاتر
          </button>
        )}
      </header>

      <div className="filters-bar">
        <div className="search-box">
          <Search size={17} />
          <input
            type="search"
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
            placeholder="ابحث بالاسم أو البريد الإلكتروني…"
            aria-label="بحث في المشرفين"
          />
        </div>

        <input
          type="text"
          className="role-filter"
          value={roleInput}
          onChange={(event) => setRoleInput(event.target.value)}
          placeholder="تصفية بالدور…"
          aria-label="تصفية بالدور"
        />

        <select
          className="status-filter"
          value={isActive}
          onChange={(event) => {
            setIsActive(event.target.value)
            setPage(1)
          }}
          aria-label="تصفية بحالة الحساب"
        >
          <option value="">كل الحالات</option>
          <option value="true">نشط</option>
          <option value="false">غير نشط</option>
        </select>
      </div>

      {isPending ? (
        <div className="state-panel">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل المشرفين…</p>
        </div>
      ) : isError ? (
        <div className="state-panel state-panel-error">
          <p>{userFacingError(error)}</p>
          <button type="button" className="ghost-button" onClick={() => refetch()}>
            <RefreshCw size={16} />
            إعادة المحاولة
          </button>
        </div>
      ) : data.items.length === 0 ? (
        <div className="state-panel">
          <ShieldCheck size={26} />
          <p>{hasFilters ? 'لا توجد نتائج مطابقة لعوامل التصفية.' : 'لا يوجد مشرفون بعد.'}</p>
        </div>
      ) : (
        <>
          <div className="table-wrap">
            <table className="places-table">
              <thead>
                <tr>
                  <th>المشرف</th>
                  <th>الأدوار</th>
                  <th>الصلاحيات</th>
                  <th>الحالة</th>
                  <th>الإجراء</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((user: AdminUserRead) => (
                  <tr key={user.id}>
                    <td>
                      <div className="place-name-cell">
                        <span className="user-avatar" aria-hidden="true">
                          {user.full_name.trim().charAt(0) || '؟'}
                        </span>
                        <div className="place-name-info">
                          <Link to={`/users/${user.id}`}>{user.full_name}</Link>
                          <span className="cell-muted" dir="ltr">{user.email}</span>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div className="role-chips">
                        {user.roles.length > 0 ? (
                          user.roles.map((name) => (
                            <span key={name} className="service-chip">{name}</span>
                          ))
                        ) : (
                          <span className="cell-muted">—</span>
                        )}
                      </div>
                    </td>
                    <td>{user.permissions.length}</td>
                    <td>
                      {user.is_active ? (
                        <span className="badge badge-active">نشط</span>
                      ) : (
                        <span className="badge badge-inactive">غير نشط</span>
                      )}
                    </td>
                    <td>
                      <Link
                        className="ghost-button icon-button"
                        to={`/users/${user.id}`}
                        aria-label={`تفاصيل ${user.full_name}`}
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
              {isFetching ? ' …' : ''}
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
