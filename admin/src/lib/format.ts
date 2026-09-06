/** Formats an ISO date string for display in Arabic admin tables; '—' for null/invalid. */
export function formatDate(value: string | null) {
  if (!value) return '—'
  try {
    return new Intl.DateTimeFormat('ar', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value))
  } catch {
    return value
  }
}
