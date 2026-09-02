import 'package:flutter/material.dart';

import '../theme/wayn_colors.dart';
import '../navigation/wayn_actions.dart';

/// حالة إخفاء إشعار تسجيل الدخول على مستوى الجلسة الحالية.
///
/// تُحفظ في الذاكرة فقط حتى لا يعود الإشعار للظهور بشكل مزعج
/// عند كل rebuild أثناء نفس الجلسة، ويُعاد ظهوره في فتح التطبيق القادم.
class WaynGuestBannerDismissed extends ValueNotifier<bool> {
  WaynGuestBannerDismissed._() : super(false);
  static final WaynGuestBannerDismissed instance =
      WaynGuestBannerDismissed._();
}

/// إشعار "قم بتسجيل الدخول" للزائر.
///
/// - يظهر أسفل الهيدر مباشرة (ليس جزءًا من الهيدر).
/// - خلفية شفافة أنيقة مع حدود ناعمة تحافظ على وضوح النص والأزرار.
/// - يمكن إخفاؤه بثلاث طرق: زر X، السحب للأعلى، أو التمرير للأعلى.
/// - لا يعاد ظهوره خلال الجلسة الحالية بعد الإخفاء.
class WaynGuestBanner extends StatefulWidget {
  /// اتجاه تخطيط العنصر داخل الشاشة:
  /// [WaynGuestBannerPlacement.overlay] فوق المحتوى (Shell)،
  /// [WaynGuestBannerPlacement.inline] كعنصر داخل قائمة قابلة للتمرير.
  final WaynGuestBannerPlacement placement;

  const WaynGuestBanner({
    super.key,
    this.placement = WaynGuestBannerPlacement.overlay,
  });

  @override
  State<WaynGuestBanner> createState() => _WaynGuestBannerState();
}

enum WaynGuestBannerPlacement { overlay, inline }

class _WaynGuestBannerState extends State<WaynGuestBanner> {
  /// يُخفى تلقائيًا عند التمرير للأعلى (يُستدعى من الصفحات الممرّرة).
  static void dismissForSession() {
    if (!WaynGuestBannerDismissed.instance.value) {
      WaynGuestBannerDismissed.instance.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WaynGuestBannerDismissed.instance,
      builder: (context, dismissed, _) {
        if (dismissed) return const SizedBox.shrink();

        final banner = _buildBanner(context);

        if (widget.placement == WaynGuestBannerPlacement.inline) {
          // داخل قائمة: يختفي عند السحب للأعلى أو التمرير بعيدًا.
          return Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Dismissible(
              key: const ValueKey('wayn_guest_banner_inline'),
              direction: DismissDirection.up,
              onDismissed: (_) => dismissForSession(),
              child: banner,
            ),
          );
        }

        return Dismissible(
          key: const ValueKey('wayn_guest_banner_overlay'),
          direction: DismissDirection.up,
          onDismissed: (_) => dismissForSession(),
          child: banner,
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    final colors = context.waynColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // خلفية شفافة أنيقة مع Blur خفيف عبر لون شبه شفاف.
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brand.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: colors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'قم بتسجيل الدخول للاستمتاع بجميع ميزات وين',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              dismissForSession();
              openLoginAndRebuild(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'تسجيل الدخول',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 4),
          // زر الإغلاق X.
          InkResponse(
            onTap: () => dismissForSession(),
            radius: 18,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}