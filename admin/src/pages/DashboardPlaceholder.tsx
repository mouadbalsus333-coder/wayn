import { LockKeyhole, Sparkles } from 'lucide-react'
import { useAuth } from '../auth/useAuth'

export function DashboardPlaceholder() {
  const { admin } = useAuth()
  return (
    <div className="placeholder-page">
      <div className="placeholder-icon"><Sparkles size={22} /></div>
      <p className="eyebrow">تم التحقق من الجلسة</p>
      <h2>مساحة الإدارة جاهزة للخطوة التالية</h2>
      <p className="muted">تم تأسيس الاتصال الآمن مع WAYN. ستظهر الوحدات الإدارية هنا بعد اعتماد المرحلة التالية.</p>
      <div className="session-chip"><LockKeyhole size={15} /> {admin?.email}</div>
    </div>
  )
}
