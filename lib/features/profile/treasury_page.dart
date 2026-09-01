import 'package:flutter/material.dart';

import '../../core/theme/wayn_colors.dart';

/// صفحة "الخزانة": العناصر التي اشتراها المستخدم من المتجر.
///
/// ملاحظة: نظام شراء عناصر المتجر غير موجود حاليًا في Backend،
/// لذلك لا تُعرض بيانات وهمية؛ تظهر هذه الشاشة حالة فارغة صادقة
/// حتى يصبح نظام المشتريات متاحًا في الخادم (جدول Database +
/// Model + Endpoint لحفظ/جلب مشتريات المستخدم).
///
/// يعمل السحب للأسفل هنا على إعادة فحص الخزانة؛ وسيقوم بجلب
/// العناصر الحقيقية فور توفر backend (endpoint) للمشتريات.
class TreasuryPage extends StatefulWidget {
  const TreasuryPage({super.key});

  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  Future<void> _refresh() async {
    // لا توجد بيانات مشتريات حقيقية بعد (backend غير متاح)،
    // فنعيد فحص الحالة الفارغة بعد لحظة قصيرة فقط لإتمام التفاعل.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              _header(context, colors),
              Expanded(
                child: RefreshIndicator(
                  color: colors.brand,
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      const SizedBox(height: 120),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 52,
                          color: colors.brand,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          'خزانتك فارغة',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                        ),
                        child: Text(
                          'العناصر التي تشتريها من المتجر ستظهر هنا '
                          'بعد توفّر نظام المشتريات.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    WaynColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            behavior: HitTestBehavior.opaque,
            child: Container(
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
                Icons.arrow_forward_rounded,
                color: colors.textPrimary,
                size: 23,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'الخزانة',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 46),
        ],
      ),
    );
  }
}
