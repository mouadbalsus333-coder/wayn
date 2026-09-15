import 'package:flutter/material.dart';

import '../../core/theme/wayn_colors.dart';
import '../../models/contribution.dart';
import '../../services/auth_service.dart';
import '../../services/contribution_service.dart';

/// صفحة «مهامي» — سجل عمليات المستخدم السابقة (المساهمات).
///
/// كل عنصر هنا يمثل تنفيذًا مستقلًا لمهمة، ويستخدم نفس حالات الـ Backend:
/// PENDING / APPROVED / REJECTED / CANCELLED. النقاط المعروضة هي
/// `points_awarded` القادمة من الـ Backend (0 إذا لم تُمنح بعد).
class MyContributionsPage extends StatefulWidget {
  const MyContributionsPage({super.key});

  @override
  State<MyContributionsPage> createState() => _MyContributionsPageState();
}

class _MyContributionsPageState extends State<MyContributionsPage> {
  final AuthService _auth = AuthService();
  final ContributionService _contributionService = ContributionService();

  List<Contribution> _contributions = [];

  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }

    try {
      final user = await _auth.getCurrentUser();

      final items = <Contribution>[];

      if (user != null) {
        // تُجلب كل عمليات المستخدم دون فلترة بالحالة حتى تظهر
        // قيد المراجعة والموافق عليها والمرفوضة معًا.
        var offset = 0;
        const pageSize = 50;

        while (true) {
          final page = await _contributionService.getContributionsByUser(
            user.id,
            offset: offset,
            limit: pageSize,
          );

          if (page.isEmpty) {
            break;
          }

          items.addAll(page);

          if (page.length < pageSize) {
            break;
          }

          offset += pageSize;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _contributions = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'مهامي',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: colors.textSecondary),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(colors),
        ),
      ),
    );
  }

  Widget _buildBody(WaynColors colors) {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: CircularProgressIndicator(color: colors.brand),
        ),
      );
    }

    if (_loadFailed) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.cloud_off_rounded, size: 52, color: colors.textMuted),
          const SizedBox(height: 14),
          Text(
            'تعذر تحميل مهامك.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: FilledButton.styleFrom(backgroundColor: colors.brand),
          ),
        ],
      );
    }

    if (_contributions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.history_rounded, size: 48, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'لم تنفذ أي مهمة بعد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        Text(
          'سجل عملياتك',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'كل تنفيذ لمهمة يظهر هنا كسجل مستقل يمكن تتبعه.',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 14),
        ..._contributions.map((c) => _contributionCard(colors, c)),
      ],
    );
  }

  Widget _contributionCard(WaynColors colors, Contribution contribution) {
    final isCreatePlace = contribution.type == ContributionType.createPlace;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isCreatePlace
                      ? Icons.place_rounded
                      : Icons.stars_rounded,
                  color: isCreatePlace
                      ? colors.brand
                      : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(contribution.type),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contribution.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              _statusPill(colors, contribution.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(contribution.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
              Text(
                _pointsLabel(contribution),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _pointsColor(colors, contribution),
                ),
              ),
            ],
          ),
          if (contribution.status == ContributionStatus.rejected &&
              (contribution.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'سبب الرفض: ${contribution.rejectionReason}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.danger,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(WaynColors colors, ContributionStatus status) {
    switch (status) {
      case ContributionStatus.pending:
        return _pill(
          colors,
          label: 'قيد المراجعة ⏳',
          color: colors.warning,
          background: colors.warning.withValues(alpha: 0.12),
        );

      case ContributionStatus.approved:
        return _pill(
          colors,
          label: 'تمت الموافقة ✓',
          color: colors.brand,
          background: colors.surfaceAlt,
        );

      case ContributionStatus.rejected:
        return _pill(
          colors,
          label: 'مرفوضة ✕',
          color: colors.danger,
          background: colors.danger.withValues(alpha: 0.12),
        );

      case ContributionStatus.cancelled:
        return _pill(
          colors,
          label: 'ملغاة',
          color: colors.textMuted,
          background: colors.surfaceAlt,
        );
    }
  }

  Widget _pill(
    WaynColors colors, {
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _typeLabel(ContributionType type) {
    switch (type) {
      case ContributionType.createPlace:
        return 'إضافة مكان';
      case ContributionType.updatePlace:
        return 'تعديل مكان';
      case ContributionType.addImage:
        return 'إضافة صورة';
      case ContributionType.updateInformation:
        return 'تحديث معلومات';
      case ContributionType.verifyPlace:
        return 'التحقق من مكان';
    }
  }

  String _pointsLabel(Contribution contribution) {
    if (contribution.status == ContributionStatus.pending) {
      return '0 نقطة حاليًا';
    }

    if (contribution.pointsAwarded == 0) {
      return 'بدون نقاط';
    }

    return '+${contribution.pointsAwarded} نقطة';
  }

  Color _pointsColor(WaynColors colors, Contribution contribution) {
    if (contribution.status == ContributionStatus.approved &&
        contribution.pointsAwarded > 0) {
      return colors.brand;
    }

    if (contribution.status == ContributionStatus.rejected) {
      return colors.danger;
    }

    return colors.textMuted;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year/$month/$day - $hour:$minute';
  }
}
