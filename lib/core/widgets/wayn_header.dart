import 'package:flutter/material.dart';

import '../theme/wayn_colors.dart';
import '../../features/location/saved_locations_store.dart';
import '../../features/location/widgets/location_selector_sheet.dart';
import '../../features/map/location_picker_page.dart';
import '../../services/social_service.dart';

/// الهيدر الموحّد لصفحات WAYN.
///
/// يعرض دائمًا نفس الترتيب بنفس المسافات للنصين RTL:
/// [زر القائمة] [📍 الموقع الحالي] [زر الإشعارات]
///
/// عند الضغط على الموقع يفتح [showLocationSelectorSheet] لعرض المواقع
/// المحفوظة واختيار/إضافة موقع.
///
/// نقطة الإشعار تظهر فقط عند وجود إشعار حقيقي غير مقروء.
class WaynHeader extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;

  /// عناصر إضافية اختيارية تُعرض على يسار زر الإشعارات (مثل زر التحديث).
  final List<Widget>? trailing;

  const WaynHeader({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
    this.trailing,
  });

  @override
  State<WaynHeader> createState() => _WaynHeaderState();
}

class _WaynHeaderState extends State<WaynHeader> {
  static const Duration _notificationCacheDuration = Duration(seconds: 30);

  /// حالة مشتركة بين جميع نسخ WaynHeader.
  ///
  /// هذا يمنع كل صفحة من إعادة طلب حالة الإشعارات بشكل مستقل.
  static final ValueNotifier<bool> _sharedHasUnreadNotifications =
      ValueNotifier<bool>(false);

  /// الطلب الحالي المشترك، حتى لو أنشأت عدة صفحات الهيدر في نفس الوقت
  /// فلن نرسل عدة requests متزامنة.
  static Future<void>? _sharedLoadFuture;

  /// وقت آخر تحديث ناجح لحالة الإشعارات.
  static DateTime? _sharedLoadedAt;

  final SocialService _socialService = SocialService();

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  /// تحميل حالة الإشعارات من endpoint خفيف بدل تحميل قائمة كاملة
  /// من الإشعارات.
  ///
  /// يتم استخدام cache مشترك لمدة قصيرة لمنع تكرار نفس الطلب بين
  /// نسخ WaynHeader الموجودة في صفحات التطبيق.
  Future<void> _loadNotificationStatus({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final lastLoadedAt = _sharedLoadedAt;

    if (!forceRefresh &&
        lastLoadedAt != null &&
        now.difference(lastLoadedAt) < _notificationCacheDuration) {
      return;
    }

    if (_sharedLoadFuture != null) {
      await _sharedLoadFuture;
      return;
    }

    final future = _fetchSharedNotificationStatus();
    _sharedLoadFuture = future;

    try {
      await future;
    } finally {
      if (identical(_sharedLoadFuture, future)) {
        _sharedLoadFuture = null;
      }
    }
  }

  Future<void> _fetchSharedNotificationStatus() async {
    try {
      final unreadCount = await _socialService.getUnreadCount();

      _sharedHasUnreadNotifications.value = unreadCount > 0;
      _sharedLoadedAt = DateTime.now();
    } catch (_) {
      // إذا تعذر تحميل حالة الإشعارات، لا نظهر النقطة.
      _sharedHasUnreadNotifications.value = false;
    }
  }

  Future<void> _openNotifications() async {
    widget.onNotificationsPressed();

    // عند العودة من صفحة الإشعارات نعيد الفحص،
    // لأن المستخدم قد يكون علّم الإشعارات كمقروءة.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await _loadNotificationStatus(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.menu_rounded,
            onPressed: widget.onMenuPressed,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: _LocationPill(
              onTap: () => _handleLocationTap(context),
            ),
          ),

          const SizedBox(width: 10),

          ValueListenableBuilder<bool>(
            valueListenable: _sharedHasUnreadNotifications,
            builder: (context, hasUnreadNotifications, _) {
              return _HeaderIconButton(
                icon: Icons.notifications_none_rounded,
                onPressed: _openNotifications,
                showBadge: hasUnreadNotifications,
              );
            },
          ),

          ...?widget.trailing,
        ],
      ),
    );
  }

  Future<void> _handleLocationTap(BuildContext context) async {
    await SavedLocationsStore.instance.ensureLoaded();
    if (!context.mounted) return;

    final result = await showLocationSelectorSheet(context);
    if (!context.mounted || result == null) return;

    switch (result) {
      case UseGpsResult():
        await SavedLocationsStore.instance.selectGps();
        break;

      case UseSavedLocationResult(:final location):
        await SavedLocationsStore.instance.select(location.id);
        break;

      case AddLocationResult():
        await openAddLocationFlow(context);
        break;
    }
  }
}

/// تدفق إضافة موقع يدوي: خريطة اختيار → إدخال اسم → حفظ واختياره كموقع حالي.

/// إضافة موقع يدويًا عبر [LocationPickerPage] ثم طلب اسم وتخزينه. التصميم:

/// أنشئ ورق أسفلين تطلب اسم الموقع بعد اختيار الإحداثيات.
Future<String?> _promptLocationName(BuildContext context) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          'إضافة موقع',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'اسم الموقع',
            hintText: 'مثال: البيت',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF18A99A),
            ),
            child: const Text('حفظ الموقع'),
          ),
        ],
      ),
    ),
  );
}

/// يفتح خريطة اختيار الموقع، ثم يطلب اسمًا، ثم يحفظ الموقع ويختاره كموقع حالي.
Future<void> openAddLocationFlow(BuildContext context) async {
  await SavedLocationsStore.instance.ensureLoaded();
  if (!context.mounted) return;

  final coordinates = await Navigator.of(context).push<Map<String, double>>(
    MaterialPageRoute(
      builder: (_) => const LocationPickerPage(),
    ),
  );

  final latitude = coordinates?['latitude'];
  final longitude = coordinates?['longitude'];

  if (!context.mounted || latitude == null || longitude == null) return;

  final name = await _promptLocationName(context);
  if (!context.mounted || name == null || name.isEmpty) return;

  await SavedLocationsStore.instance.add(
    name: name,
    latitude: latitude,
    longitude: longitude,
  );

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'تم حفظ الموقع "$name" كموقع حالي',
        textDirection: TextDirection.rtl,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// كبسولة تعرض الموقع الحالي وتفتح ورقة المواقع عند الضغط عليها.
///
/// ورقة المواقع هي المكان الوحيد لتغيير الموقع الحالي.
class _LocationPill extends StatelessWidget {
  final VoidCallback onTap;

  const _LocationPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final store = SavedLocationsStore.instance;
    final colors = context.waynColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedBuilder(
        animation: store,
        builder: (context_, _) {
          final label = store.currentLabel;

          return Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF18A99A),
                  size: 21,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.textMuted,
                  size: 18,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool showBadge;

  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: colors.textPrimary,
              size: 23,
            ),
          ),
          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE95353),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF7F9FC),
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}