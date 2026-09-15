export type PointRuleRead = {
  id: number
  action_key: string
  points: number
  title: string
  description: string | null
  is_active: boolean
  requires_approval: boolean
  limit_per_user: number | null
  created_at: string
  updated_at: string
}

export type PointRuleUpdatePayload = {
  points?: number
  title?: string
  description?: string | null
  is_active?: boolean
  requires_approval?: boolean
  limit_per_user?: number | null
}

export type PointRuleCreatePayload = PointRuleUpdatePayload & {
  action_key: string
}
