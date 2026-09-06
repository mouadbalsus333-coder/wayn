import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ArrowRight, Eye, EyeOff, MessageSquare, RotateCcw, ShieldAlert } from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { useAuth } from '../../auth/useAuth'
import { useCommunityPosts, usePostComments } from '../../hooks/useCommunity'
import {
  useCommentVisibilityMutation,
  usePostVisibilityMutation,
} from '../../hooks/useCommunityMutations'
import { permissions } from '../../permissions/permissionNames'
import { formatDate } from '../../lib/format'
import './community.css'

/**
 * Post details + moderation view. Uses real data only: the post is located
 * in the paginated list response (no dedicated detail GET exists in the
 * backend — none was invented). Refresh-safe.
 */
export function CommunityPostPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { hasPermission } = useAuth()
  const canModerate = hasPermission(permissions.communityModerate)
  const { data, isPending, isError, error, refetch } = useCommunityPosts({
    page: 1,
    limit: 100,
  })
  const post = id ? data?.items.find((item) => item.id === id) : undefined
  const visibilityMutation = usePostVisibilityMutation()

  if (!id) return null

  if (isPending) {
    return (
      <div className="community-page">
        <div className="card state-card" aria-busy="true">
          <p>جارٍ تحميل المنشور…</p>
        </div>
      </div>
    )
  }

  if (isError) {
    return (
      <div className="community-page">
        <div className="card state-card" role="alert">
          <ShieldAlert size={24} aria-hidden />
          <p>{userFacingError(error, 'تعذر تحميل المنشور.')}</p>
          <button type="button" className="btn btn-primary" onClick={() => void refetch()}>
            <RotateCcw size={16} /> إعادة المحاولة
          </button>
        </div>
      </div>
    )
  }

  if (!post) {
    return (
      <div className="community-page">
        <div className="card state-card">
          <p>المنشور غير موجود.</p>
          <Link to="/community" className="btn btn-ghost">
            <ArrowRight size={16} /> العودة إلى القائمة
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="community-page">
      <header className="community-header">
        <div>
          <button type="button" className="btn btn-ghost btn-back" onClick={() => navigate(-1)}>
            <ArrowRight size={16} /> رجوع
          </button>
          <h2>منشور مجتمعي</h2>
          <p className="muted">
            {post.author_name ?? '—'}
            {post.author_username ? ` (@${post.author_username})` : ''} · {post.place_name ?? '—'}
          </p>
        </div>
        {canModerate && (
          <button
            type="button"
            className="btn btn-primary"
            disabled={visibilityMutation.isPending}
            onClick={() =>
              visibilityMutation.mutate({
                postId: post.id,
                payload: { is_visible: !post.is_visible },
              })
            }
          >
            {post.is_visible ? (
              <>
                <EyeOff size={16} /> إخفاء المنشور
              </>
            ) : (
              <>
                <Eye size={16} /> إظهار المنشور
              </>
            )}
          </button>
        )}
      </header>

      {visibilityMutation.isError && (
        <p className="error-note" role="alert">
          {userFacingError(visibilityMutation.error, 'تعذر تغيير حالة الظهور.')}
        </p>
      )}

      <div className="card post-details-card">
        {post.image_url && <img src={post.image_url} alt="" className="post-image" />}
        {post.text && <p className="post-body">{post.text}</p>}
        <div className="post-meta">
          <span>⭐ {post.rating ?? '—'}</span>
          <span>👍 {post.likes_count}</span>
          <span>💬 {post.comments_count}</span>
          <span>{post.is_visible ? 'ظاهر' : 'مخفي'}</span>
          <span className="cell-muted">{formatDate(post.created_at)}</span>
        </div>
      </div>

      <CommentsSection postId={post.id} canModerate={canModerate} />
    </div>
  )
}

function CommentsSection({ postId, canModerate }: { postId: string; canModerate: boolean }) {
  const [page, setPage] = useState(1)
  const [visibility, setVisibility] = useState<'all' | 'visible' | 'hidden'>('all')
  const { data, isPending, isError, error, refetch, isFetching } = usePostComments(postId, {
    page,
    limit: 50,
    is_visible: visibility === 'all' ? undefined : visibility === 'visible',
  })
  const mutation = useCommentVisibilityMutation()

  return (
    <section className="comments-section">
      <h3>
        <MessageSquare size={16} aria-hidden /> التعليقات
      </h3>

      <div className="card community-toolbar">
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
      </div>

      {mutation.isError && (
        <p className="error-note" role="alert">
          {userFacingError(mutation.error, 'تعذر تغيير حالة ظهور التعليق.')}
        </p>
      )}

      {isPending ? (
        <div className="card state-card" aria-busy="true">
          <p>جارٍ تحميل التعليقات…</p>
        </div>
      ) : isError ? (
        <div className="card state-card" role="alert">
          <ShieldAlert size={24} aria-hidden />
          <p>{userFacingError(error, 'تعذر تحميل التعليقات.')}</p>
          <button type="button" className="btn btn-primary" onClick={() => void refetch()}>
            <RotateCcw size={16} /> إعادة المحاولة
          </button>
        </div>
      ) : !data || data.items.length === 0 ? (
        <div className="card state-card">
          <p>لا توجد تعليقات مطابقة.</p>
        </div>
      ) : (
        <>
          <ul className="comments-list">
            {data.items.map((comment) => (
              <li key={comment.id} className="card comment-item">
                <div className="comment-head">
                  <strong>{comment.author_name ?? '—'}</strong>
                  {comment.author_username && (
                    <span className="cell-muted"> @{comment.author_username}</span>
                  )}
                  <span className={comment.is_visible ? 'badge badge-green' : 'badge badge-red'}>
                    {comment.is_visible ? 'ظاهر' : 'مخفي'}
                  </span>
                  <span className="cell-muted">{formatDate(comment.created_at)}</span>
                  {canModerate && (
                    <button
                      type="button"
                      className="btn btn-ghost btn-sm"
                      disabled={mutation.isPending || isFetching}
                      onClick={() =>
                        mutation.mutate({
                          commentId: comment.id,
                          payload: { is_visible: !comment.is_visible },
                        })
                      }
                    >
                      {comment.is_visible ? (
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
                </div>
                <p className="comment-text">{comment.text}</p>
              </li>
            ))}
          </ul>

          <nav className="pagination" aria-label="تنقل صفحات التعليقات">
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              disabled={data.page <= 1 || isFetching}
              onClick={() => setPage(data.page - 1)}
            >
              السابق
            </button>
            <span className="muted">
              صفحة {data.page} من {data.pages} · {data.total} تعليق
            </span>
            <button
              type="button"
              className="btn btn-ghost btn-sm"
              disabled={data.page >= data.pages || isFetching}
              onClick={() => setPage(data.page + 1)}
            >
              التالي
            </button>
          </nav>
        </>
      )}
    </section>
  )
}
