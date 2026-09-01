import 'package:flutter/material.dart';

import '../../features/auth/login_page.dart';
import '../../features/places/place_details_page.dart';
import '../../features/profile/public_profile_page.dart';
import '../../services/place_service.dart';
import 'wayn_shell.dart';

/// طلب التوجه إلى تبويب "حسابي" (يستمع إليه [WaynShell]).
final ValueNotifier<int> waynGoToProfileRequest = ValueNotifier(0);

/// يفتح شاشة تسجيل الدخول، وبعد نجاحها يعيد بناء [WaynShell] بالكامل
/// لتصبح كامل واجهة التطبيق في حالة المستخدم المسجّل (وليس الزائر).
///
/// يُستخدم هذا المسار الوحيد من جميع نقاط دخول الزائر (البنر العلوي، تبويب
/// حسابي، القائمة الجانبية، رسالة تفاعل المنشورات) لضمان تحديث حالة التطبيق
/// بشكل متّسق وبدون أخطاء تنقّل أو تسريب حالة قديمة.
void openLoginAndRebuild(BuildContext context) {
  final navigator = Navigator.of(context);

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => LoginPage(
        onAuthenticated: (user) {
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => WaynShell(user: user),
            ),
            (_) => false,
          );
        },
      ),
    ),
    (_) => false,
  );
}

/// يفتح صفحة حساب المستخدم:
/// - إذا كان هو المستخدم الحالي → ينتقل إلى تبويب حسابي.
/// - وإلا → يفتح [PublicProfilePage] لبياناته الحقيقية.
void openUserProfile(
  BuildContext context, {
  required String userId,
  required bool isOwner,
}) {
  if (isOwner) {
    waynGoToProfileRequest.value++;
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicProfilePage(userId: userId),
    ),
  );
}

/// يفتح صفحة تفاصيل مكان من placeId الحقيقي.
Future<void> openPlaceFromId(
  BuildContext context,
  String placeId,
) async {
  if (placeId.trim().isEmpty) {
    return;
  }

  var place = await PlaceService().getPlaceById(placeId);

  if (!context.mounted) return;

  if (place == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر فتح المكان المرتبط',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlaceDetailsPage(place: place),
    ),
  );
}
