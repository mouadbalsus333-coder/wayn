export type ApiErrorKind = 'unauthorized' | 'forbidden' | 'notFound' | 'conflict' | 'validation' | 'server' | 'unknown'

export class ApiError extends Error {
  readonly status: number
  readonly kind: ApiErrorKind

  constructor(status: number, message: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.kind = getErrorKind(status)
  }
}

function getErrorKind(status: number): ApiErrorKind {
  if (status === 401) return 'unauthorized'
  if (status === 403) return 'forbidden'
  if (status === 404) return 'notFound'
  if (status === 409) return 'conflict'
  if (status === 422) return 'validation'
  if (status >= 500) return 'server'
  return 'unknown'
}

export function userFacingError(error: unknown, fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.') {
  if (error instanceof ApiError) {
    if (error.kind === 'unauthorized') return 'انتهت جلسة الإدارة. سجل الدخول مرة أخرى.'
    if (error.kind === 'forbidden') return 'لا تملك الصلاحية لتنفيذ هذا الإجراء.'
    if (error.kind === 'validation') return 'تحقق من البيانات المدخلة.'
    if (error.kind === 'server') return 'الخادم غير متاح حاليًا. حاول لاحقًا.'
    return error.message || fallback
  }
  return fallback
}
