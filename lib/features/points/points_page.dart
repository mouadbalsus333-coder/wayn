import 'package:flutter/material.dart';

import '../../core/theme/wayn_colors.dart';
import '../map/location_picker_page.dart';
import '../../models/contribution.dart';
import '../../models/task.dart';
import '../../services/auth_service.dart';
import '../../services/contribution_service.dart';
import '../../services/task_service.dart';
import '../../services/user_service.dart';
import 'widgets/add_place_sheet.dart';

/// صفحة «نقاطي» — تعرض رصيد المستخدم والمهام النشطة من Backend.
///
/// القيمة النقطية لكل مهمة تأتي من النهاية الخلفية (Point Rules) وليست
/// مثبتة داخل التطبيق. مهمة «إضافة مكان جديد» تطلق تدفقًا يفتح الخريطة ثم
/// نموذج مكان في Bottom Sheet، ويُرسل المساهمة كـ `pending` للمراجعة.
class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  static const String _addPlaceActionKey = 'add_place';

  final UserService _userService = UserService();
  final TaskService _taskService = TaskService();
  final AuthService _auth = AuthService();
  final ContributionService _contributionService = ContributionService();

  int _points = 0;
  List<Task> _tasks = [];

  bool _hasPendingCreate = false;
  bool _hasApprovedCreate = false;

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
      final points = await _userService.getMyPoints();
      final tasks = await _taskService.getActiveTasks();
      final user = await _auth.getCurrentUser();

      var hasPending = false;
      var hasApproved = false;

      if (user != null) {
        final pending = await _contributionService.getContributionsByUser(
          user.id,
          status: ContributionStatus.pending,
          limit: 100,
        );

        final approved = await _contributionService.getContributionsByUser(
          user.id,
          status: ContributionStatus.approved,
          limit: 100,
        );

        hasPending = pending.any(
          (c) => c.type == ContributionType.createPlace,
        );

        hasApproved = approved.any(
          (c) => c.type == ContributionType.createPlace,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _points = points;
        _tasks = tasks;
        _hasPendingCreate = hasPending;
        _hasApprovedCreate = hasApproved;
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

  /// تدفق «إضافة مكان»: فتح الخريطة لاختيار الموقع ← ثم فتح نموذج الإرسال.
  Future<void> _startAddPlace(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final coordinates = await navigator.push<Map<String, double>>(
      MaterialPageRoute(
        builder: (_) => const LocationPickerPage(),
      ),
    );

    if (!mounted) {
      return;
    }

    final latitude = coordinates?['latitude'];
    final longitude = coordinates?['longitude'];

    if (latitude == null || longitude == null) {
      return;
    }

    final contribution = await navigator.push<Contribution>(
      MaterialPageRoute(
        builder: (_) => AddPlaceSheet(
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );

    if (!mounted || contribution == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'تم إرسال مساهمتك للمراجعة. شكرًا لمساهمتك في تحسين WAYN 💚',
          textDirection: TextDirection.rtl,
        ),
      ),
    );

    await _load();
  }

  bool _isAddPlace(Task task) =>
      (task.metadata['action_key']?.toString() ?? '') == _addPlaceActionKey;
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
            'نقاطي',
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
          child: _buildBody(colors, context),
        ),
      ),
    );
  }

  Widget _buildBody(WaynColors colors, BuildContext context) {
    if (_loading) {
      return _loadingState(colors);
    }

    if (_loadFailed) {
      return _errorState(colors, context);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _balanceHero(colors),
        const SizedBox(height: 22),
        Text(
          'المهام',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'أكمل المهام التالية واكسب نقاطًا تساهم في تحسين WAYN.',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 14),
        if (_tasks.isEmpty)
          _emptyTasks(colors)
        else
          ..._tasks.map((task) => _taskCard(colors, context, task)),
      ],
    );
  }

  Widget _balanceHero(WaynColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brand, colors.brandDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.brand.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نقاطي',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_points',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          Text(
            'نقطة',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

Widget _taskCard(
    WaynColors colors,
    BuildContext context,
    Task task,
  ) {
    final isAddPlace = _isAddPlace(task);

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
                  isAddPlace
                      ? Icons.place_rounded
                      : Icons.stars_rounded,
                  color: isAddPlace ? colors.brand : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+${task.rewardPoints} نقطة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: colors.brand,
                ),
              ),
              _taskAction(colors, context, task, isAddPlace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskAction(
    WaynColors colors,
    BuildContext context,
    Task task,
    bool isAddPlace,
  ) {
    if (!isAddPlace) {
      return _statusPill(
        colors,
        label: 'قريبًا',
        color: colors.textMuted,
        background: colors.surfaceAlt,
      );
    }

    if (_hasPendingCreate) {
      return _statusPill(
        colors,
        label: 'قيد المراجعة ⏳',
        color: colors.warning,
        background: colors.warning.withValues(alpha: 0.12),
      );
    }

    if (_hasApprovedCreate) {
      return _statusPill(
        colors,
        label: 'تمت الموافقة ✓',
        color: colors.brand,
        background: colors.surfaceAlt,
      );
    }

    return FilledButton(
      onPressed: () => _startAddPlace(context),
      style: FilledButton.styleFrom(
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      ),
      child: const Text(
        'ابدأ',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _statusPill(
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

Widget _loadingState(WaynColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: CircularProgressIndicator(color: colors.brand),
      ),
    );
  }

  Widget _errorState(WaynColors colors, BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 52, color: colors.textMuted),
        const SizedBox(height: 14),
        Text(
          'تعذر تحميل النقاط والمهام.',
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

  Widget _emptyTasks(WaynColors colors) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle_rounded, size: 40, color: colors.brand),
          const SizedBox(height: 10),
          Text(
            'لا توجد مهام متاحة حاليًا.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

}