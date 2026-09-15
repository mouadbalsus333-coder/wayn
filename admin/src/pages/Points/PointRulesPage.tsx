import { useState } from 'react'
import {
  Award,
  Loader2,
  Pencil,
  Plus,
  RefreshCw,
  Save,
  X,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { usePointRules } from '../../hooks/usePointRules'
import {
  useCreatePointRuleMutation,
  useUpdatePointRuleMutation,
} from '../../hooks/usePointRuleMutations'
import type { PointRuleRead } from '../../types/pointRule'
import './points.css'

type DraftState = {
  mode: 'edit' | 'new'
  rule: PointRuleRead | null
  title: string
  description: string
  points: string
  actionKey: string
  isActive: boolean
}

const emptyDraft: DraftState = {
  mode: 'new',
  rule: null,
  title: '',
  description: '',
  points: '0',
  actionKey: '',
  isActive: true,
}

function draftFromRule(rule: PointRuleRead): DraftState {
  return {
    mode: 'edit',
    rule,
    title: rule.title,
    description: rule.description ?? '',
    points: String(rule.points),
    actionKey: rule.action_key,
    isActive: rule.is_active,
  }
}

export function PointRulesPage() {
  const { data, isPending, isError, error, refetch } = usePointRules()
  const createMutation = useCreatePointRuleMutation()
  const updateMutation = useUpdatePointRuleMutation()

  const [draft, setDraft] = useState<DraftState | null>(null)
  const [formError, setFormError] = useState<string | null>(null)

  const openDraft = (state: DraftState) => {
    setFormError(null)
    setDraft(state)
  }

  const submitDraft = () => {
    if (!draft) return

    const points = Number.parseInt(draft.points, 10)

    if (!draft.title.trim()) {
      setFormError('اسم المهمة مطلوب.')
      return
    }

    if (Number.isNaN(points) || points < 0) {
      setFormError('قيمة النقاط يجب أن تكون رقمًا موجبًا.')
      return
    }

    if (draft.mode === 'new' && !draft.actionKey.trim()) {
      setFormError('مفتاح المهمة مطلوب.')
      return
    }

    setFormError(null)

    if (draft.mode === 'edit' && draft.rule) {
      updateMutation.mutate(
        {
          id: draft.rule.id,
          payload: {
            title: draft.title.trim(),
            description: draft.description.trim() || null,
            points,
            is_active: draft.isActive,
          },
        },
        {
          onSuccess: () => setDraft(null),
        },
      )
      return
    }

    createMutation.mutate(
      {
        action_key: draft.actionKey.trim(),
        title: draft.title.trim(),
        description: draft.description.trim() || null,
        points,
        is_active: draft.isActive,
      },
      {
        onSuccess: () => setDraft(null),
      },
    )
  }

  const busy = createMutation.isPending || updateMutation.isPending

  return (
    <div className="points-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">نظام النقاط والمساهمات</p>

          <h2>مهام النقاط</h2>

          <p className="muted">
            إدارة مهام المساعدة وقيم مكافآت النقاط. المهام غير الفعالة لا تظهر
            للمستخدمين.
          </p>
        </div>

        <button
          type="button"
          className="primary-button"
          onClick={() => openDraft(emptyDraft)}
        >
          <Plus size={17} />
          مهمة جديدة
        </button>
      </header>

      {draft && (
        <div className="state-panel card points-editor">
          <div className="points-editor-header">
            <h3>
              {draft.mode === 'new'
                ? 'مهمة جديدة'
                : `تعديل: ${draft.rule?.title}`}
            </h3>

            <button
              type="button"
              className="ghost-button"
              onClick={() => setDraft(null)}
            >
              <X size={16} />
              إلغاء
            </button>
          </div>

          <div className="points-editor-grid">
            <label>
              <span>اسم المهمة</span>

              <input
                value={draft.title}
                onChange={(e) =>
                  setDraft({
                    ...draft,
                    title: e.target.value,
                  })
                }
                placeholder="أضف مكانًا جديدًا"
              />
            </label>

            <label>
              <span>قيمة المكافأة (نقطة)</span>

              <input
                type="number"
                min={0}
                value={draft.points}
                onChange={(e) =>
                  setDraft({
                    ...draft,
                    points: e.target.value,
                  })
                }
              />
            </label>

            {draft.mode === 'new' && (
              <label>
                <span>مفتاح المهمة (إنجليزي)</span>

                <input
                  value={draft.actionKey}
                  onChange={(e) =>
                    setDraft({
                      ...draft,
                      actionKey: e.target.value,
                    })
                  }
                  placeholder="add_place"
                />
              </label>
            )}

            <label className="points-editor-checkbox">
              <input
                type="checkbox"
                checked={draft.isActive}
                onChange={(e) =>
                  setDraft({
                    ...draft,
                    isActive: e.target.checked,
                  })
                }
              />

              <span>فعّالة (تظهر للمستخدمين)</span>
            </label>

            <label className="points-editor-wide">
              <span>الوصف</span>

              <input
                value={draft.description}
                onChange={(e) =>
                  setDraft({
                    ...draft,
                    description: e.target.value,
                  })
                }
                placeholder="ساعدنا في إضافة أماكن جديدة إلى WAYN"
              />
            </label>
          </div>

          {formError && (
            <p className="points-form-error">
              {formError}
            </p>
          )}

          <div className="points-editor-actions">
            <button
              type="button"
              className="primary-button"
              onClick={submitDraft}
              disabled={busy}
            >
              {busy ? (
                <Loader2 className="spin" size={16} />
              ) : (
                <Save size={16} />
              )}

              حفظ
            </button>
          </div>
        </div>
      )}

      {isPending ? (
        <div className="state-panel card">
          <Loader2 className="spin" size={28} />
          <p>جارٍ تحميل مهام النقاط…</p>
        </div>
      ) : isError ? (
        <div className="state-panel card">
          <p>
            {userFacingError(error, 'تعذر تحميل مهام النقاط.')}
          </p>

          <button
            type="button"
            className="ghost-button"
            onClick={() => refetch()}
          >
            <RefreshCw size={16} />
            إعادة المحاولة
          </button>
        </div>
      ) : (
        <div className="points-grid">
          {data?.map((rule) => (
            <article
              key={rule.id}
              className={`card points-card${
                rule.is_active ? '' : ' is-inactive'
              }`}
            >
              <div className="points-card-header">
                <span className="points-card-icon">
                  <Award size={20} />
                </span>

                <span
                  className={`status-pill ${
                    rule.is_active ? 'is-active' : 'is-muted'
                  }`}
                >
                  {rule.is_active ? 'فعّالة' : 'غير فعّالة'}
                </span>
              </div>

              <h3>{rule.title}</h3>

              {rule.description && (
                <p className="muted">
                  {rule.description}
                </p>
              )}

              <div className="points-card-footer">
                <strong className="points-reward">
                  +{rule.points} نقطة
                </strong>

                <button
                  type="button"
                  className="ghost-button"
                  onClick={() => openDraft(draftFromRule(rule))}
                >
                  <Pencil size={15} />
                  تعديل
                </button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  )
}
