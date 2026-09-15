import { apiRequest } from './client'
import type {
  PointRuleCreatePayload,
  PointRuleRead,
  PointRuleUpdatePayload,
} from '../types/pointRule'

/** `GET /api/v1/admin/point-rules` — requires `points.manage`. */
export function listPointRules(): Promise<PointRuleRead[]> {
  return apiRequest<PointRuleRead[]>('/api/v1/admin/point-rules')
}

/** `POST /api/v1/admin/point-rules` — requires `points.manage`. */
export function createPointRule(payload: PointRuleCreatePayload): Promise<PointRuleRead> {
  return apiRequest<PointRuleRead>('/api/v1/admin/point-rules', {
    method: 'POST',
    body: payload,
  })
}

/** `PATCH /api/v1/admin/point-rules/{id}` — requires `points.manage`. */
export function updatePointRule(id: number, payload: PointRuleUpdatePayload): Promise<PointRuleRead> {
  return apiRequest<PointRuleRead>(`/api/v1/admin/point-rules/${id}`, {
    method: 'PATCH',
    body: payload,
  })
}
