import {
  Activity,
  AlertTriangle,
  Clock,
  FileClock,
  Loader2,
  MapPin,
  MessageSquare,
  RefreshCw,
  Star,
  UserCheck,
  Users,
  Wallet,
  type LucideIcon,
} from 'lucide-react'
import { userFacingError } from '../api/errors'
import { useDashboardSummary } from '../hooks/useDashboardSummary'
import type { DashboardSummary } from '../types/dashboard'

type MetricDef = {
  key: keyof DashboardSummary
  label: string
  hint: string
  icon: LucideIcon
}

const metricDefs: MetricDef[] = [
  { key: 'total_users', label: 'إجمالي المستخدمين', hint: 'حسابات مسجلة في النظام', icon: Users },
  { key: 'active_users', label: 'المستخدمون النشطون', hint: 'حسابات نشطة ومفعّلة', icon: UserCheck },
  { key: 'total_places', label: 'إجمالي الأماكن', hint: 'أماكن غير محذوفة', icon: MapPin },
  { key: 'pending_places', label: 'أماكن قيد المراجعة', hint: 'بانتظار التحقق', icon: Clock },
  { key: 'pending_contributions', label: 'مساهمات قيد المراجعة', hint: 'بانتظار المراجعة', icon: FileClock },
  { key: 'visible_community_posts', label: 'منشورات المجتمع', hint: 'منشورات مرئية', icon: MessageSquare },
  { key: 'visible_reviews', label: 'تقييمات مرئية', hint: 'تقييمات معروضة', icon: Star },
  { key: 'wallet_recharge_operations', label: 'عمليات شحن المحفظة', hint: 'إجمالي عمليات الشحن', icon: Wallet },
]

const numberFormatter = new Intl.NumberFormat('en-US')

function formatNumber(value: number | null | undefined) {
  if (value == null) return '—'
  return numberFormatter.format(value)
}

export function DashboardPage() {
  const { data, isPending, isError, error, refetch } = useDashboardSummary()

  if (isPending) {
    return (
      <div className="state-panel">
        <Loader2 className="spin" size={28} />
        <p>جارٍ تحميل لوحة الإحصائيات…</p>
      </div>
    )
  }

  if (isError) {
    return (
      <div className="state-panel state-error">
        <AlertTriangle size={30} />
        <h2>تعذّر تحميل البيانات</h2>
        <p>{userFacingError(error)}</p>
        <button type="button" className="primary-button" onClick={() => refetch()}>
          <RefreshCw size={17} />
          إعادة المحاولة
        </button>
      </div>
    )
  }

  const visible = data ? metricDefs.filter((metric) => data[metric.key] != null) : []

  if (visible.length === 0) {
    return (
      <div className="state-panel">
        <Activity size={30} />
        <h2>لا توجد بيانات متاحة</h2>
        <p>لا تملك صلاحية الوصول إلى أي إحصائية في النظام حالياً.</p>
      </div>
    )
  }

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <p className="eyebrow">نظرة عامة</p>
        <h2>لوحة الإحصائيات</h2>
        <p className="muted">أرقام تُحسب مباشرة من قاعدة بيانات WAYN وفق صلاحياتك.</p>
      </header>
      <div className="metric-grid">
        {visible.map((metric) => {
          const Icon = metric.icon
          const value = data?.[metric.key] ?? null
          return (
            <div className="metric-card" key={metric.key}>
              <span className="metric-icon">
                <Icon size={20} />
              </span>
              <div className="metric-body">
                <span className="metric-label">{metric.label}</span>
                <strong className="metric-value">{formatNumber(value)}</strong>
                <span className="metric-note">{metric.hint}</span>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}