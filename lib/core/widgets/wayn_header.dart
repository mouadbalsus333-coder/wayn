import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/wayn_colors.dart';
import '../../features/location/saved_locations_store.dart';
import '../../features/location/widgets/location_selector_sheet.dart';
import '../../features/map/location_picker_page.dart';
import '../../services/social_service.dart';

/// الحالة المشتركة لقائمة WAYN.
/// يغيّرها [showWaynMenu] فيتحرك زر القائمة تلقائيًا (هامبرغر ⇄ إغلاق).
final ValueNotifier<bool> waynMenuIsOpen = ValueNotifier<bool>(false);

class WaynHeader extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;
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

  static final ValueNotifier<bool> _sharedHasUnreadNotifications =
      ValueNotifier<bool>(false);

  static Future<void>? _sharedLoadFuture;
  static DateTime? _sharedLoadedAt;

  final SocialService _socialService = SocialService();

  @override
  void initState() {
    super.initState();
    _loadNotificationStatus();
  }

  Future<void> _loadNotificationStatus({bool forceRefresh = false}) async {
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
      _sharedHasUnreadNotifications.value = false;
    }
  }

  Future<void> _openNotifications() async {
    widget.onNotificationsPressed();

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await _loadNotificationStatus(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: waynMenuIsOpen,
            builder: (context, isOpen, _) {
              return _MenuButton(
                isOpen: isOpen,
                onPressed: widget.onMenuPressed,
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _LocationSelector(
              onTap: () => _handleLocationTap(context),
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<bool>(
            valueListenable: _sharedHasUnreadNotifications,
            builder: (context, hasUnread, _) {
              return _BellButton(
                hasUnread: hasUnread,
                onPressed: _openNotifications,
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

// ---------------------------------------------------------------------------
// عنصر ضغط مشترك.
// ---------------------------------------------------------------------------
class _Pressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final double pressedScale;
  final String semanticsLabel;

  const _Pressable({
    required this.onTap,
    required this.child,
    required this.semanticsLabel,
    this.pressedScale = 0.92,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// زر القائمة.
// ---------------------------------------------------------------------------
class _MenuButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.isOpen,
    required this.onPressed,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
      value: widget.isOpen ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _MenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOpen != widget.isOpen) {
      widget.isOpen ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return _Pressable(
      semanticsLabel: 'قائمة وين',
      onTap: widget.onPressed,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_controller.value);

            return Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Color.lerp(colors.surfaceElevated, colors.brand, t),
                borderRadius: BorderRadius.circular(
                  lerpDouble(16, 23, t)!,
                ),
              ),
              child: Center(
                child: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _controller,
                  size: 24,
                  color: Color.lerp(
                    colors.textPrimary,
                    Colors.white,
                    t,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// زر الإشعارات.
// ---------------------------------------------------------------------------
class _BellButton extends StatefulWidget {
  final bool hasUnread;
  final VoidCallback onPressed;

  const _BellButton({
    required this.hasUnread,
    required this.onPressed,
  });

  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton>
    with TickerProviderStateMixin {
  static const Color _alert = Color(0xFFE95353);

  late final AnimationController _ring;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _ring = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    if (widget.hasUnread) {
      _startAttention();
    }
  }

  @override
  void didUpdateWidget(covariant _BellButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.hasUnread == widget.hasUnread) return;

    if (widget.hasUnread) {
      _startAttention();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  void _startAttention() {
    _ring.forward(from: 0);
    _pulse.repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;
    final active = widget.hasUnread;

    return _Pressable(
      semanticsLabel: 'الإشعارات',
      onTap: widget.onPressed,
      child: RepaintBoundary(
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: active
                ? colors.brand.withValues(alpha: 0.12)
                : colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _ring,
                builder: (context, child) {
                  final t = _ring.value;
                  final angle =
                      math.sin(t * math.pi * 5) * 0.30 * (1 - t);

                  return Transform.rotate(
                    angle: angle,
                    alignment: Alignment.topCenter,
                    child: child,
                  );
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Icon(
                    active
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    key: ValueKey<bool>(active),
                    size: 25,
                    color: active
                        ? colors.brand
                        : colors.textPrimary,
                  ),
                ),
              ),
              if (active)
                Positioned(
                  top: 6,
                  right: 6,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        final t =
                            Curves.easeOut.transform(_pulse.value);

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 10 + (10 * t),
                              height: 10 + (10 * t),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _alert.withValues(
                                  alpha: 0.38 * (1 - t),
                                ),
                              ),
                            ),
                            Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: _alert,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// محدد الموقع.
// ---------------------------------------------------------------------------
class _LocationSelector extends StatefulWidget {
  final VoidCallback onTap;

  const _LocationSelector({
    required this.onTap,
  });

  @override
  State<_LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<_LocationSelector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;
    final store = SavedLocationsStore.instance;

    return _Pressable(
      semanticsLabel: 'الموقع الحالي',
      pressedScale: 0.975,
      onTap: widget.onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsetsDirectional.only(
          start: 6,
          end: 10,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          children: [
            RepaintBoundary(
              child: _PinBadge(
                pulse: _pulse,
                color: colors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) {
                  final label = store.currentLabel;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 21,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (current, previous) {
                            return Stack(
                              alignment:
                                  AlignmentDirectional.centerStart,
                              children: [
                                ...previous,
                                if (current != null) current,
                              ],
                            );
                          },
                          transitionBuilder: (
                            child,
                            animation,
                          ) {
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            );

                            return FadeTransition(
                              opacity: curved,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.35),
                                  end: Offset.zero,
                                ).animate(curved),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            label,
                            key: ValueKey<String>(label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: colors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PinBadge extends StatelessWidget {
  final Animation<double> pulse;
  final Color color;

  const _PinBadge({
    required this.pulse,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final t = Curves.easeOut.transform(pulse.value);

              return Transform.scale(
                scale: 1 + (0.6 * t),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(
                      alpha: 0.30 * (1 - t),
                    ),
                  ),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                  ),
                ),
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Icon(
                  Icons.location_on_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// تدفق إضافة موقع.
// ---------------------------------------------------------------------------
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
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(
                controller.text.trim(),
              );
            },
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

/// يفتح خريطة اختيار الموقع، ثم يطلب اسمًا، ثم يحفظ الموقع.
Future<void> openAddLocationFlow(BuildContext context) async {
  await SavedLocationsStore.instance.ensureLoaded();

  if (!context.mounted) return;

  final coordinates =
      await Navigator.of(context).push<Map<String, double>>(
    MaterialPageRoute(
      builder: (_) => const LocationPickerPage(),
    ),
  );

  final latitude = coordinates?['latitude'];
  final longitude = coordinates?['longitude'];

  if (!context.mounted || latitude == null || longitude == null) {
    return;
  }

  final name = await _promptLocationName(context);

  if (!context.mounted || name == null || name.isEmpty) {
    return;
  }

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