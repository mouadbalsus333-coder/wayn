import { useState } from 'react'
import {
  BarChart3,
  CheckCircle2,
  Loader2,
  RefreshCw,
  Search,
  ShieldCheck,
  Wallet as WalletIcon,
  ArrowLeftRight,
} from 'lucide-react'
import { userFacingError } from '../../api/errors'
import { lookupWallet } from '../../api/wallet'
import { useAuth } from '../../auth/useAuth'
import {
  useRechargeStats,
  useRecharges,
  useTransfers,
  useWalletReports,
} from '../../hooks/useWallet'
import { useRechargeMutation } from '../../hooks/useWalletMutations'
import { permissions } from '../../permissions/permissionNames'
import { formatDate } from '../../lib/format'
import type {
  WalletLookup,
  WalletRecharge,
  WalletTransferListParams,
} from '../../types/wallet'
import './wallet.css'
import '../Places/places.css'
import '../Places/place-actions.css'

const PAGE_SIZE = 20

type WalletTab = 'recharge' | 'history' | 'reports' | 'transfers'

type LookupMode = 'wallet_number' | 'user_id'

export function WalletPage() {
  const { hasPermission } = useAuth()
  const canRecharge = hasPermission(permissions.walletRecharge)
  const canViewTransfers = hasPermission(permissions.walletRead)

  const [activeTab, setActiveTab] = useState<WalletTab>('recharge')
  const [page, setPage] = useState(1)
  const [transferPage, setTransferPage] = useState(1)

  const {
    data: history,
    isPending,
    isFetching,
    isError,
    error,
    refetch,
  } = useRecharges({
    offset: (page - 1) * PAGE_SIZE,
    limit: PAGE_SIZE,
  })

  const statsQuery = useRechargeStats()
  const reportsQuery = useWalletReports()

  const transferParams: WalletTransferListParams = {
    offset: (transferPage - 1) * PAGE_SIZE,
    limit: PAGE_SIZE,
  }

  const transfersQuery = useTransfers(transferParams)

  const [lookupMode, setLookupMode] =
    useState<LookupMode>('wallet_number')
  const [lookupInput, setLookupInput] = useState('')
  const [lookupLoading, setLookupLoading] = useState(false)
  const [lookupError, setLookupError] = useState<string | null>(null)
  const [lookupResult, setLookupResult] =
    useState<WalletLookup | null>(null)
  const [amount, setAmount] = useState('')
  const [note, setNote] = useState('')
  const [confirmOpen, setConfirmOpen] = useState(false)
  const [success, setSuccess] = useState<string | null>(null)

  const handleLookup = async () => {
    const query = lookupInput.trim()

    if (!query) {
      setLookupError(
        lookupMode === 'wallet_number'
          ? 'أدخل رقم المحفظة.'
          : 'أدخل معرّف المستخدم (User ID).',
      )
      return
    }

    setLookupLoading(true)
    setLookupError(null)
    setSuccess(null)

    try {
      const result =
        lookupMode === 'wallet_number'
          ? await lookupWallet({ wallet_number: query })
          : await lookupWallet({ user_id: query })

      setLookupResult(result)
    } catch (e) {
      setLookupResult(null)
      setLookupError(
        userFacingError(e, 'تعذر العثور على المحفظة.'),
      )
    } finally {
      setLookupLoading(false)
    }
  }

  const totalPages = history
    ? Math.max(1, Math.ceil(history.total / PAGE_SIZE))
    : 1

  const transferTotalPages = transfersQuery.data
    ? Math.max(
        1,
        Math.ceil(
          transfersQuery.data.total / PAGE_SIZE,
        ),
      )
    : 1

  return (
    <div className="wallet-page">
      <header className="places-header">
        <div>
          <p className="eyebrow">الإدارة المالية</p>
          <h2>المحفظة</h2>
          <p className="muted">
            البحث عن محفظة، شحن العملات، استعراض السجل،
            التقارير، والتحويلات.
          </p>
        </div>
      </header>

      {success && (
        <p className="success-note" role="status">
          <CheckCircle2 size={16} /> {success}
        </p>
      )}

      {/* Tab Navigation */}
      <div className="wallet-tabs">
        <button
          type="button"
          className={`wallet-tab ${
            activeTab === 'recharge' ? 'active' : ''
          }`}
          onClick={() => setActiveTab('recharge')}
        >
          <ShieldCheck size={16} /> الشحن
        </button>

        <button
          type="button"
          className={`wallet-tab ${
            activeTab === 'history' ? 'active' : ''
          }`}
          onClick={() => setActiveTab('history')}
        >
          <WalletIcon size={16} /> السجل
        </button>

        <button
          type="button"
          className={`wallet-tab ${
            activeTab === 'reports' ? 'active' : ''
          }`}
          onClick={() => setActiveTab('reports')}
        >
          <BarChart3 size={16} /> التقارير
        </button>

        {canViewTransfers && (
          <button
            type="button"
            className={`wallet-tab ${
              activeTab === 'transfers' ? 'active' : ''
            }`}
            onClick={() => setActiveTab('transfers')}
          >
            <ArrowLeftRight size={16} /> التحويلات
          </button>
        )}
      </div>

      {/* Stats Overview */}
      <div className="info-grid wallet-stats">
        <div className="info-card metric">
          <h3>إجمالي العمليات</h3>
          <span className="metric-value">
            {statsQuery.data?.total_operations ?? '—'}
          </span>
        </div>

        <div className="info-card metric">
          <h3>إجمالي الشحن</h3>
          <span className="metric-value">
            {statsQuery.data?.total_coins_recharged ?? '—'}
          </span>
        </div>

        <div className="info-card metric">
          <h3>مؤكدة</h3>
          <span className="metric-value">
            {statsQuery.data?.confirmed_count ?? '—'}
          </span>
        </div>

        <div className="info-card metric">
          <h3>فاشلة</h3>
          <span className="metric-value">
            {statsQuery.data?.failed_count ?? '—'}
          </span>
        </div>
      </div>

      {/* Recharge Tab */}
      {activeTab === 'recharge' && (
        <div className="card wallet-recharge-card">
          <h3>شحن محفظة</h3>

          <p className="muted">
            ابحث برقم المحفظة أو معرّف المستخدم لتأكيد
            بيانات الحساب قبل الشحن.
          </p>

          <div
            className="wallet-tabs"
            role="tablist"
            aria-label="طريقة البحث"
          >
            <button
              type="button"
              className={`wallet-tab ${
                lookupMode === 'wallet_number' ? 'active' : ''
              }`}
              onClick={() => {
                setLookupMode('wallet_number')
                setLookupResult(null)
                setLookupError(null)
                setSuccess(null)
              }}
            >
              <WalletIcon size={16} /> رقم المحفظة
            </button>

            <button
              type="button"
              className={`wallet-tab ${
                lookupMode === 'user_id' ? 'active' : ''
              }`}
              onClick={() => {
                setLookupMode('user_id')
                setLookupResult(null)
                setLookupError(null)
                setSuccess(null)
              }}
            >
              <Search size={16} /> User ID
            </button>
          </div>

          <div className="filters-bar">
            <div className="search-box">
              <Search size={17} />

              <input
                type="text"
                dir="ltr"
                value={lookupInput}
                onChange={(e) =>
                  setLookupInput(e.target.value)
                }
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    void handleLookup()
                  }
                }}
                placeholder={
                  lookupMode === 'wallet_number'
                    ? 'رقم المحفظة…'
                    : 'User ID…'
                }
                aria-label={
                  lookupMode === 'wallet_number'
                    ? 'رقم المحفظة'
                    : 'معرّف المستخدم'
                }
              />
            </div>

            <button
              type="button"
              className="primary-button"
              disabled={lookupLoading}
              onClick={() => void handleLookup()}
            >
              {lookupLoading ? (
                <Loader2
                  className="spin"
                  size={17}
                />
              ) : (
                <Search size={17} />
              )}

              {lookupLoading
                ? 'جارٍ البحث…'
                : 'بحث'}
            </button>
          </div>

          {lookupError && (
            <div
              className="mutation-error"
              role="alert"
            >
              {lookupError}
            </div>
          )}

          {lookupResult && (
            <div className="wallet-result">
              <div className="place-hero-card compact">
                <div className="place-hero-main">
                  <h2>{lookupResult.full_name}</h2>

                  <p
                    className="muted"
                    dir="ltr"
                  >
                    @{lookupResult.username}
                  </p>

                  <div className="place-hero-meta">
                    <span className="service-chip">
                      رقم المحفظة:{' '}
                      {lookupResult.wallet_number}
                    </span>

                    <span className="service-chip">
                      الرصيد الحالي:{' '}
                      {lookupResult.coins_balance}
                    </span>

                    {lookupResult.is_verified ? (
                      <span className="badge badge-active">
                        موثّق
                      </span>
                    ) : (
                      <span className="badge badge-inactive">
                        غير موثّق
                      </span>
                    )}

                    {lookupResult.is_active ? (
                      <span className="badge badge-active">
                        نشط
                      </span>
                    ) : (
                      <span className="badge badge-inactive">
                        غير نشط
                      </span>
                    )}
                  </div>

                  {!canRecharge && (
                    <p className="self-note">
                      لا تملك صلاحية الشحن
                      (wallet.recharge).
                    </p>
                  )}
                </div>
              </div>

              {canRecharge && (
                <div className="recharge-form">
                  <div className="form-field">
                    <label htmlFor="wallet-amount">
                      المبلغ (عملات)
                    </label>

                    <input
                      id="wallet-amount"
                      type="number"
                      min={1}
                      step={1}
                      value={amount}
                      onChange={(e) =>
                        setAmount(e.target.value)
                      }
                      placeholder="أدخل مبلغًا أكبر من صفر"
                    />
                  </div>

                  <div className="form-field full">
                    <label htmlFor="wallet-note">
                      ملاحظة (اختياري)
                    </label>

                    <input
                      id="wallet-note"
                      value={note}
                      onChange={(e) =>
                        setNote(e.target.value)
                      }
                      placeholder="ملاحظة داخلية لعملية الشحن"
                    />
                  </div>

                  <div className="form-actions">
                    <button
                      type="button"
                      className="primary-button"
                      disabled={
                        !amount.trim() ||
                        Number(amount) <= 0 ||
                        !Number.isInteger(Number(amount))
                      }
                      onClick={() => {
                        setSuccess(null)
                        setConfirmOpen(true)
                      }}
                    >
                      <ShieldCheck size={16} />
                      متابعة الشحن
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* History Tab */}
      {activeTab === 'history' && (
        <div className="wallet-history">
          <h3>سجل الشحن</h3>

          {isPending ? (
            <div className="state-panel card">
              <Loader2
                className="spin"
                size={28}
              />
              <p>جارٍ تحميل السجل…</p>
            </div>
          ) : isError ? (
            <div className="state-panel card">
              <p>
                {userFacingError(
                  error,
                  'تعذر تحميل سجل الشحن.',
                )}
              </p>

              <button
                type="button"
                className="ghost-button"
                onClick={() => void refetch()}
              >
                <RefreshCw size={16} />
                إعادة المحاولة
              </button>
            </div>
          ) : history &&
            history.items.length === 0 ? (
            <div className="state-panel card">
              <WalletIcon size={26} />
              <p>لا توجد عمليات شحن بعد.</p>
            </div>
          ) : (
            <>
              <div className="table-wrap">
                <table className="places-table">
                  <thead>
                    <tr>
                      <th>رقم المحفظة</th>
                      <th>المبلغ</th>
                      <th>الرصيد قبل</th>
                      <th>الرصيد بعد</th>
                      <th>الحالة</th>
                      <th>المسؤول</th>
                      <th>التاريخ</th>
                    </tr>
                  </thead>

                  <tbody>
                    {history?.items.map((item) => (
                      <tr key={item.recharge_id}>
                        <td dir="ltr">
                          {item.wallet_number}
                        </td>

                        <td>{item.amount}</td>

                        <td>
                          {item.balance_before}
                        </td>

                        <td>
                          {item.balance_after}
                        </td>

                        <td>
                          {item.status === 'CONFIRMED' ? (
                            <span className="badge badge-active">
                              مؤكدة
                            </span>
                          ) : item.status === 'FAILED' ? (
                            <span className="badge badge-inactive">
                              فاشلة
                            </span>
                          ) : (
                            <span className="badge badge-pending">
                              قيد الانتظار
                            </span>
                          )}
                        </td>

                        <td className="cell-muted">
                          {item.admin_email}
                        </td>

                        <td className="cell-muted">
                          {formatDate(item.created_at)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="pagination-row">
                <span className="pagination-info">
                  {history?.total} نتيجة — صفحة{' '}
                  {page} من {totalPages}
                  {isFetching ? ' …' : ''}
                </span>

                <div className="pagination-controls">
                  <button
                    type="button"
                    className="ghost-button icon-button"
                    disabled={page <= 1}
                    onClick={() =>
                      setPage((c) => c - 1)
                    }
                    aria-label="السابق"
                  >
                    السابق
                  </button>

                  <button
                    type="button"
                    className="ghost-button icon-button"
                    disabled={
                      page >= totalPages
                    }
                    onClick={() =>
                      setPage((c) => c + 1)
                    }
                    aria-label="التالي"
                  >
                    التالي
                  </button>
                </div>
              </div>
            </>
          )}
        </div>
      )}

      {/* Reports Tab */}
      {activeTab === 'reports' && (
        <div className="wallet-reports">
          <h3>تقارير المحفظة</h3>

          <p className="muted">
            إحصائيات مجمعة عن عمليات الشحن والتحويلات.
          </p>

          {reportsQuery.isPending ? (
            <div className="state-panel card">
              <Loader2
                className="spin"
                size={28}
              />
              <p>جارٍ تحميل التقارير…</p>
            </div>
          ) : reportsQuery.isError ? (
            <div className="state-panel card">
              <p>
                {userFacingError(
                  reportsQuery.error,
                  'تعذر تحميل التقارير.',
                )}
              </p>

              <button
                type="button"
                className="ghost-button"
                onClick={() =>
                  void reportsQuery.refetch()
                }
              >
                <RefreshCw size={16} />
                إعادة المحاولة
              </button>
            </div>
          ) : reportsQuery.data ? (
            <>
              <div className="info-grid wallet-stats">
                <div className="info-card metric">
                  <h3>
                    إجمالي عمليات الشحن
                  </h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .total_recharges
                    }
                  </span>
                </div>

                <div className="info-card metric">
                  <h3>
                    مبلغ الشحن المؤكد
                  </h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .total_recharge_amount
                    }
                  </span>
                </div>

                <div className="info-card metric">
                  <h3>شحنات مؤكدة</h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .confirmed_recharges
                    }
                  </span>
                </div>

                <div className="info-card metric">
                  <h3>شحنات فاشلة</h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .failed_recharges
                    }
                  </span>
                </div>
              </div>

              <div className="info-grid wallet-stats">
                <div className="info-card metric">
                  <h3>
                    إجمالي التحويلات
                  </h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .total_transfers
                    }
                  </span>
                </div>

                <div className="info-card metric">
                  <h3>
                    تحويلات مؤكدة
                  </h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .confirmed_transfers
                    }
                  </span>
                </div>

                <div className="info-card metric">
                  <h3>
                    تحويلات فاشلة
                  </h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .failed_transfers
                    }
                  </span>
                </div>

                <div className="info-card metric">
                  <h3>
                    مبلغ التحويلات المؤكدة
                  </h3>

                  <span className="metric-value">
                    {
                      reportsQuery.data
                        .total_transfer_amount
                    }
                  </span>
                </div>
              </div>
            </>
          ) : null}
        </div>
      )}

      {/* Transfers Tab */}
      {activeTab === 'transfers' &&
        canViewTransfers && (
          <div className="wallet-transfers">
            <h3>مراقبة التحويلات</h3>

            <p className="muted">
              قائمة التحويلات بين المحافظ مع إمكانية البحث
              والتصفية.
            </p>

            {transfersQuery.isPending ? (
              <div className="state-panel card">
                <Loader2
                  className="spin"
                  size={28}
                />
                <p>
                  جارٍ تحميل التحويلات…
                </p>
              </div>
            ) : transfersQuery.isError ? (
              <div className="state-panel card">
                <p>
                  {userFacingError(
                    transfersQuery.error,
                    'تعذر تحميل التحويلات.',
                  )}
                </p>

                <button
                  type="button"
                  className="ghost-button"
                  onClick={() =>
                    void transfersQuery.refetch()
                  }
                >
                  <RefreshCw size={16} />
                  إعادة المحاولة
                </button>
              </div>
            ) : transfersQuery.data &&
              transfersQuery.data.items.length ===
                0 ? (
              <div className="state-panel card">
                <ArrowLeftRight size={26} />
                <p>
                  لا توجد تحويلات بعد.
                </p>
              </div>
            ) : (
              <>
                <div className="table-wrap">
                  <table className="places-table">
                    <thead>
                      <tr>
                        <th>المرسل</th>
                        <th>المستقبل</th>
                        <th>الأصل</th>
                        <th>المبلغ</th>
                        <th>الحالة</th>
                        <th>التاريخ</th>
                      </tr>
                    </thead>

                    <tbody>
                      {transfersQuery.data?.items.map(
                        (item) => (
                          <tr key={item.id}>
                            <td>
                              <div className="transfer-cell">
                                <span className="transfer-name">
                                  {item.sender_name ??
                                    '—'}
                                </span>

                                {item.sender_wallet_number && (
                                  <span
                                    className="transfer-wallet"
                                    dir="ltr"
                                  >
                                    {
                                      item.sender_wallet_number
                                    }
                                  </span>
                                )}
                              </div>
                            </td>

                            <td>
                              <div className="transfer-cell">
                                <span className="transfer-name">
                                  {item.receiver_name ??
                                    '—'}
                                </span>

                                {item.receiver_wallet_number && (
                                  <span
                                    className="transfer-wallet"
                                    dir="ltr"
                                  >
                                    {
                                      item.receiver_wallet_number
                                    }
                                  </span>
                                )}
                              </div>
                            </td>

                            <td>{item.asset}</td>

                            <td>{item.amount}</td>

                            <td>
                              {item.status ===
                              'CONFIRMED' ? (
                                <span className="badge badge-active">
                                  مؤكدة
                                </span>
                              ) : item.status ===
                                'FAILED' ? (
                                <span className="badge badge-inactive">
                                  فاشلة
                                </span>
                              ) : item.status ===
                                'REVERSED' ? (
                                <span className="badge badge-inactive">
                                  معكوسة
                                </span>
                              ) : (
                                <span className="badge badge-pending">
                                  قيد الانتظار
                                </span>
                              )}
                            </td>

                            <td className="cell-muted">
                              {formatDate(
                                item.created_at,
                              )}
                            </td>
                          </tr>
                        ),
                      )}
                    </tbody>
                  </table>
                </div>

                <div className="pagination-row">
                  <span className="pagination-info">
                    {transfersQuery.data?.total}{' '}
                    نتيجة — صفحة {transferPage}{' '}
                    من {transferTotalPages}
                    {transfersQuery.isFetching
                      ? ' …'
                      : ''}
                  </span>

                  <div className="pagination-controls">
                    <button
                      type="button"
                      className="ghost-button icon-button"
                      disabled={
                        transferPage <= 1
                      }
                      onClick={() =>
                        setTransferPage(
                          (c) => c - 1,
                        )
                      }
                      aria-label="السابق"
                    >
                      السابق
                    </button>

                    <button
                      type="button"
                      className="ghost-button icon-button"
                      disabled={
                        transferPage >=
                        transferTotalPages
                      }
                      onClick={() =>
                        setTransferPage(
                          (c) => c + 1,
                        )
                      }
                      aria-label="التالي"
                    >
                      التالي
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        )}

      {/* Recharge Confirmation Modal */}
      {lookupResult &&
        confirmOpen &&
        activeTab === 'recharge' && (
          <RechargeConfirmModal
            lookup={lookupResult}
            amount={Number(amount)}
            note={note}
            onClose={() => setConfirmOpen(false)}
            onSuccess={(recharge) => {
              setLookupResult((current) =>
                current
                  ? {
                      ...current,
                      coins_balance:
                        recharge.balance_after,
                    }
                  : current,
              )

              setConfirmOpen(false)
              setAmount('')
              setNote('')
              setSuccess(
                `تمت عملية الشحن بنجاح. الرصيد الجديد: ${recharge.balance_after.toLocaleString()} عملة.`,
              )
            }}
          />
        )}
    </div>
  )
}

type RechargeConfirmModalProps = {
  lookup: WalletLookup
  amount: number
  note: string
  onClose: () => void
  onSuccess: (recharge: WalletRecharge) => void
}

function RechargeConfirmModal({
  lookup,
  amount,
  note,
  onClose,
  onSuccess,
}: RechargeConfirmModalProps) {
  const rechargeMutation =
    useRechargeMutation()

  const handleConfirm = () => {
    if (
      rechargeMutation.isPending ||
      amount <= 0 ||
      !Number.isInteger(amount)
    ) {
      return
    }

    rechargeMutation.mutate(
      {
        target_user_id: lookup.user_id,
        amount,
        note: note.trim() || null,
      },
      {
        onSuccess: (recharge) => {
          onSuccess(recharge)
        },
      },
    )
  }

  return (
    <div
      className="modal-backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (
          event.target === event.currentTarget &&
          !rechargeMutation.isPending
        ) {
          onClose()
        }
      }}
    >
      <div
        className="modal-card"
        role="dialog"
        aria-modal="true"
        aria-labelledby="recharge-confirm-title"
      >
        <div className="modal-header">
          <div>
            <h2 id="recharge-confirm-title">
              تأكيد شحن المحفظة
            </h2>

            <p className="muted">
              راجع بيانات العملية قبل تنفيذ الشحن.
            </p>
          </div>

          <button
            type="button"
            className="ghost-button icon-button"
            onClick={onClose}
            disabled={rechargeMutation.isPending}
            aria-label="إغلاق"
          >
            ×
          </button>
        </div>

        <div className="modal-body">
          <div className="recharge-confirm-grid">
            <div className="info-card">
              <span className="muted">
                اسم المستخدم
              </span>

              <strong>
                {lookup.full_name}
              </strong>
            </div>

            <div className="info-card">
              <span className="muted">
                Username
              </span>

              <strong dir="ltr">
                @{lookup.username}
              </strong>
            </div>

            <div className="info-card">
              <span className="muted">
                رقم المحفظة
              </span>

              <strong dir="ltr">
                {lookup.wallet_number}
              </strong>
            </div>

            <div className="info-card">
              <span className="muted">
                الرصيد الحالي
              </span>

              <strong>
                {lookup.coins_balance.toLocaleString()}
              </strong>
            </div>
          </div>

          <div className="recharge-amount-confirm">
            <span>مبلغ الشحن</span>

            <strong>
              {amount.toLocaleString()} عملة
            </strong>
          </div>

          {note.trim() && (
            <div className="recharge-note-confirm">
              <span className="muted">
                الملاحظة
              </span>

              <p>{note.trim()}</p>
            </div>
          )}

          <div className="recharge-balance-preview">
            <span>الرصيد بعد الشحن</span>

            <strong>
              {(
                lookup.coins_balance + amount
              ).toLocaleString()}{' '}
              عملة
            </strong>
          </div>

          {rechargeMutation.isError && (
            <div
              className="mutation-error"
              role="alert"
            >
              {userFacingError(
                rechargeMutation.error,
                'تعذر تنفيذ عملية الشحن.',
              )}
            </div>
          )}
        </div>

        <div className="modal-actions">
          <button
            type="button"
            className="ghost-button"
            onClick={onClose}
            disabled={rechargeMutation.isPending}
          >
            إلغاء
          </button>

          <button
            type="button"
            className="primary-button"
            onClick={handleConfirm}
            disabled={
              rechargeMutation.isPending ||
              amount <= 0 ||
              !Number.isInteger(amount)
            }
          >
            {rechargeMutation.isPending ? (
              <>
                <Loader2
                  className="spin"
                  size={16}
                />
                جارٍ تنفيذ الشحن...
              </>
            ) : (
              <>
                <ShieldCheck size={16} />
                تأكيد الشحن
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}