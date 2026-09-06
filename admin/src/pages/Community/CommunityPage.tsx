import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Eye,
  EyeOff,
  MessageSquare,
  RotateCcw,
  Search,
  ShieldAlert,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAuth } from '../../auth/useAuth'
import { useCommunityPosts } from '../../hooks/useCommunity'
import { usePostVisibilityMutation } from '../../hooks/useCommunityMutations'
import { permissions } from '../../permissions/permissionNames'
import type { CommunityPostRead } from '../../types/community'
import { formatDate } from '../../lib/format'
import './community.css'

const PAGE_SIZE = 20

export function CommunityPage() {
  const { hasPermission } = useAuth()
  const canModerate = hasPermission(permissions.communityModerate)

  const [page, setPage] = useState(1)
  const [searchInput, setSearchInput] = useState('')
  const [search, setSearch] = useState('')
  const [visibility, setVisibility] = useState<'all' | 'visible' | 'hidden'>('all')

  // Debounced server-side search (350ms), same pattern as Places.
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, 350)
    return () => clearTimeout(timer)
  }, [searchInput])

  const params = useMemo(
    () => ({
      page,
      limit: PAGE_SIZE,
      search: search || undefined,
      is_visible: visibility === 'all' ? undefined : visibility === 'visible',
    }),
    [page, search, visibility],
  )

  const { data, isPending, isError, error, refetch, isFetching } = useCommunityPosts(params)
  const visibilityMutation = usePostVisibilityMutation()

  const handleToggleVisibility = (post: CommunityPostRead) => {
    if (!canModerate || visibilityMutation.isPending) return
    visibilityMutation.mutate({ postId: post.id, payload: { is_visible: !post.is_visible } })
  }

  return (
    <div className="community-page">
      <header className="community-header">
        <div>
          <h2>إشراف المجتمع</h2>
          <p className="muted">مراجعة منشورات المجتمع والتحكم في ظهورها داخل التطبيق.</p>
        </div>
      </header>

      <div className="card community-toolbar">
        <label className="filter-field search-field">
          <span className="filter-label">بحث</span>
          <span className="search-box">
            <Search size={16} aria-hidden />
            <input
              type="text"
              value={searchInput}
              placeholder="ابحث في نص المنشور أو اسم الكاتب أو المكان…"
              onChange={(event) => setSearchInput(event.target.value)}
            />
          </span>
        </label>
        <label className="filter-field">
          <span className="filter-label">حالة الظهور</span>
          <select
            value={visibility}
            onChange={(event) => {
              setVisibility(event.target.value as typeof visibility)
              setPage(1)
            }}
          >
            <option value="all">الكل</option>
            <option value="visible">ظاهر</option>
            <option value="hidden">مخفي</option>
          </select>
        </label>
        {(search !== '' || visibility !== 'all') && (
          <button
            type="button"
            className="btn btn-ghost"
            onClick={() => {
              setSearchInput('')
              setSearch('')
              setVisibility('all')
              setPage(1)
            }}
          >
            <RotateCcw size={16} /> مسح الفلاتر
          </button>
        )}
      </div>

      {visibilityMutation.isError && (
        <p className="error-note" role="alert">
          {userFacingError(visibilityMutation.error, 'تعذر تغيير حالة الظهور.')}
        </p>
      )}

      <PostsResult
        isPending={isPending}
        isError={isError}
        error={error}
        data={data}
        isFetching={isFetching}
        canModerate={canModerate}
        onToggle={handleToggleVisibility}
        onRetry={() => void refetch()}
        onPageChange={setPage}
      />
    </div>
  )
}

function PostsResult({
  isPending,
  isError,
  error,
  data,
  isFetching,
  canModerate,
  onToggle,
  onRetry,
  onPageChange,
}: {
  isPending: boolean
  isError: boolean
  error: unknown
  data?: { items: CommunityPostRead[]; page: number; pages: number; total: number }
  isFetching: boolean
  canModerate: boolean
  onToggle: (post: CommunityPostRead) => void
  onRetry: () => void
  onPageChange: (page: number) => void
}) {
  if (isPending) {
    return (
      <div className="card state-card" aria-busy="true">
        <p>جارٍ تحميل المنشورات…</p>
      </div>
    )
  }
  if (isError) {
    return (
      <div className="card state-card" role="alert">
        <ShieldAlert size={24} aria-hidden />
        <p>{userFacingError(error, 'تعذر تحميل المنشورات.')}</p>
        <button type="button" className="btn btn-primary" onClick={onRetry}>
          <RotateCcw size={16} /> إعادة المحاولة
        </button>
      </div>
    )
  }
  if (!data || data.items.length === 0) {
    return (
      <div className="card state-card">
        <MessageSquare size={24} aria-hidden />
        <p>لا توجد منشورات مطابقة.</p>
      </div>
    )
  }
  return (
    <>
      <div className="card table-card">
        <table className="community-table">
          <thead>
            <tr>
              <th>المنشور</th>
              <th>الكاتب</th>
              <th>المكان</th>
              <th>التفاعل</th>
              <th>الظهور</th>
              <th>التاريخ</th>
              <th>التعليقات</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((post) => (
              <tr key={post.id}>
                <td className="post-cell">
                  <div className="post-line">
                    {post.image_url && (
                      <img src={post.image_url} alt="" className="post-thumb" loading="lazy" />
                    )}
                    <span className="post-text">{post.text ?? '— (صورة فقط)'}</span>
                  </div>
                  {post.rating !== null && <span className="rating">⭐ {post.rating}</span>}
                </td>
                <td>
                  {post.author_name ?? '—'}
                  {post.author_username && (
                    <span className="cell-muted"> @{post.author_username}</span>
                  )}
                </td>
                <td>
                  {post.place_name ?? '—'}
                  {post.place_city && <span className="cell-muted"> · {post.place_city}</span>}
                </td>
                <td>
                  👍 {post.likes_count} · 💬 {post.comments_count}
                </td>
                <td>
                  {post.is_visible ? (
                    <span className="badge badge-green">ظاهر</span>
                  ) : (
                    <span className="badge badge-red">مخفي</span>
                  )}
                </td>
                <td className="cell-muted">{formatDate(post.created_at)}</td>
                <td className="actions-cell">
                  <Link to={`/community/posts/${post.id}`} className="btn btn-ghost btn-sm">
                    <MessageSquare size={14} /> عرض ({post.comments_count})
                  </Link>
                  {canModerate && (
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      disabled={isFetching}
                      onClick={() => onToggle(post)}
                    >
                      {post.is_visible ? (
                        <>
                          <EyeOff size={14} /> إخفاء
                        </>
                      ) : (
                        <>
                          <Eye size={14} /> إظهار
                        </>
                      )}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <nav className="pagination" aria-label="تنقل الصفحات">
        <button
          type="button"
          className="btn btn-ghost btn-sm"
          disabled={data.page <= 1 || isFetching}
          onClick={() => onPageChange(data.page - 1)}
        >
          السابق
        </button>
        <span className="muted">
          صفحة {data.page} من {data.pages} · {data.total} منشور
        </span>
        <button
          type="button"
          className="btn btn-ghost btn-sm"
          disabled={data.page >= data.pages || isFetching}
          onClick={() => onPageChange(data.page + 1)}
        >
          التالي
        </button>
      </nav>
    </>
  )
}
