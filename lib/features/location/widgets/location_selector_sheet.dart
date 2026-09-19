import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/saved_location.dart';
import '../saved_locations_store.dart';

/// نتيجة اختارها المستخدم من قائمة المواقع.
sealed class LocationSheetResult {
  const LocationSheetResult();
}

class UseGpsResult extends LocationSheetResult {
  const UseGpsResult();
}

class UseSavedLocationResult extends LocationSheetResult {
  final SavedLocation location;

  const UseSavedLocationResult(this.location);
}

class AddLocationResult extends LocationSheetResult {
  const AddLocationResult();
}

/// قائمة مواقع عائمة تظهر مباشرة أسفل العنصر الذي استدعاها.
///
/// القائمة تظهر كـ Popover عائم مرتبط بصريًا بزر الموقع،
/// ولا تظهر من أسفل الشاشة أو من حافة الشاشة.
Future<LocationSheetResult?> showLocationSelectorSheet(
  BuildContext context,
) async {
  final renderObject = context.findRenderObject();

  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }

  final anchorBox = renderObject;

  final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);
  final anchorSize = anchorBox.size;

  final anchorRect = Rect.fromLTWH(
    anchorTopLeft.dx,
    anchorTopLeft.dy,
    anchorSize.width,
    anchorSize.height,
  );

  return showGeneralDialog<LocationSheetResult>(
    context: context,

    // مهم:
    // إبقاء الـ popup داخل الـ Navigator الحالي يمنع إنشاء
    // Route على الـ root navigator بشكل غير ضروري.
    useRootNavigator: false,

    barrierDismissible: true,
    barrierLabel: 'مواقعي',
    barrierColor: Colors.transparent,

    // حركة قصيرة وناعمة تناسب Popover عائم.
    transitionDuration: const Duration(milliseconds: 260),

    pageBuilder: (context, animation, secondaryAnimation) {
      return _LocationSelectorOverlay(
        anchorRect: anchorRect,
      );
    },

    transitionBuilder: (
      context,
      animation,
      secondaryAnimation,
      child,
    ) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      // ظهور سريع وخفيف بدل Fade طويل.
      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(
            0.0,
            0.78,
            curve: Curves.easeOut,
          ),
          reverseCurve: Curves.easeIn,
        ),
      );

      // تكبير بسيط جدًا من نقطة الارتباط مع الزر.
      final scaleAnimation = Tween<double>(
        begin: 0.965,
        end: 1.0,
      ).animate(curvedAnimation);

      // حركة عمودية صغيرة جدًا.
      // الهدف أن تشعر أن القائمة "انفتحت" تحت الزر
      // وليس أنها تحركت من مكان آخر.
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, -0.018),
        end: Offset.zero,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
    },
  );
}

class _LocationSelectorOverlay extends StatefulWidget {
  final Rect anchorRect;

  const _LocationSelectorOverlay({
    required this.anchorRect,
  });

  @override
  State<_LocationSelectorOverlay> createState() =>
      _LocationSelectorOverlayState();
}

class _LocationSelectorOverlayState
    extends State<_LocationSelectorOverlay> {
  @override
  void initState() {
    super.initState();

    // تأكد من تحميل المواقع قبل العرض.
    SavedLocationsStore.instance.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final store = SavedLocationsStore.instance;

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    const horizontalMargin = 12.0;
    const verticalGap = 8.0;

    final availableWidth =
        screenSize.width - (horizontalMargin * 2);

    final popupWidth = math.min(
      math.max(widget.anchorRect.width, 300.0),
      math.min(360.0, availableWidth),
    );

    final anchorCenterX = widget.anchorRect.center.dx;

    double left = anchorCenterX - (popupWidth / 2);

    left = left.clamp(
      horizontalMargin,
      screenSize.width - popupWidth - horizontalMargin,
    );

    final top = widget.anchorRect.bottom + verticalGap;

    final availableHeight =
        screenSize.height - top - 12;

    final maxPopupHeight = math.min(
      screenSize.height * 0.68,
      math.max(220.0, availableHeight),
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: popupWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxPopupHeight,
              ),
              child: _buildPopup(store),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopup(SavedLocationsStore store) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 30,
            spreadRadius: 0,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            spreadRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Color(0xFFECEFF3),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AnimatedBuilder(
          animation: store,
          builder: (context, _) {
            final locations = store.locations;
            final selected = store.selectedLocation;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 14),

                _buildHeader(),

                const SizedBox(height: 10),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      top: 2,
                      bottom: 2,
                    ),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildGpsTile(
                        store,
                        selected,
                      ),
                      ...locations.map(
                        (location) => _buildLocationTile(
                          store,
                          location,
                          selected,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                _buildAddButton(),

                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE8F8F6),
                borderRadius: BorderRadius.all(
                  Radius.circular(11),
                ),
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: Color(0xFF18A99A),
                size: 19,
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'مواقعي',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsTile(
    SavedLocationsStore store,
    SavedLocation? selected,
  ) {
    final active = selected == null;

    return _tileContainer(
      active: active,
      onTap: () {
        Navigator.of(context).pop(
          const UseGpsResult(),
        );
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F6),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFF18A99A),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموقع الحالي (GPS)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'موقع الجهاز الفعلي',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8993A3),
                  ),
                ),
              ],
            ),
          ),
          if (active)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF18A99A),
              size: 21,
            ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(
    SavedLocationsStore store,
    SavedLocation location,
    SavedLocation? selected,
  ) {
    final active = selected?.id == location.id;

    return _tileContainer(
      active: active,
      onTap: () {
        Navigator.of(context).pop(
          UseSavedLocationResult(location),
        );
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFE8F8F6)
                  : const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: active
                  ? const Color(0xFF18A99A)
                  : const Color(0xFF697386),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? const Color(0xFF172033)
                        : const Color(0xFF263247),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${location.latitude.toStringAsFixed(4)} , '
                  '${location.longitude.toStringAsFixed(4)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8993A3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (active)
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF18A99A),
              size: 21,
            )
          else
            GestureDetector(
              onTap: () => store.remove(location.id),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD95353),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileContainer({
    required bool active,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 3,
        ),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFF0FBFA)
              : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: active
                ? const Color(0xFF18A99A)
                : const Color(0xFFE8ECF1),
            width: active ? 1.4 : 1,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).pop(
            const AddLocationResult(),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF18A99A),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 12,
          ),
        ),
        icon: const Icon(
          Icons.add_location_alt_rounded,
          size: 19,
        ),
        label: const Text(
          'إضافة موقع',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}