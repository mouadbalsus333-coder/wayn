import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';
import '../../../models/contribution.dart';
import '../../../services/contribution_service.dart';

/// نموذج إضافة مكان جديد يظهر كـ Bottom Sheet بعد اختيار الموقع على الخريطة.
///
/// يُفتح بـ [Navigator.push] من صفحة «نقاطي» ويستقبل الإحداثيات المختارة على
/// الخريطة سابقًا (لا يُطلب من المستخدم اختيار الموقع مرة ثانية). عند الإرسال
/// ينشئ `PlaceContribution` بحالة `pending` فقط — لا يُنشأ مكان معتمد مباشرة —
/// ثم يُعيد المساهمة إلى المُستدعي عبر `Navigator.pop(Contribution)`.
class AddPlaceSheet extends StatefulWidget {
  final double latitude;
  final double longitude;

  const AddPlaceSheet({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<AddPlaceSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _website = TextEditingController();

  final ContributionService _contributionService = ContributionService();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _city.dispose();
    _description.dispose();
    _phone.dispose();
    _website.dispose();

    super.dispose();
  }

  Future<void> _submit(BuildContext context) async {
    final name = _name.text.trim();
    final category = _category.text.trim();
    final city = _city.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'اسم المكان مطلوب.');
      return;
    }

    if (category.isEmpty) {
      setState(() => _error = 'التصنيف مطلوب.');
      return;
    }

    if (city.isEmpty) {
      setState(() => _error = 'المدينة مطلوبة.');
      return;
    }

    if (_submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final navigator = Navigator.of(context);

    final payload = <String, dynamic>{
      'name': name,
      'category_name': category,
      'city': city,
      'latitude': widget.latitude,
      'longitude': widget.longitude,
      'image_url': '',
      'is_active': false,
      'description': _optional(_description.text),
      'phone': _optional(_phone.text),
      'website': _optional(_website.text),
    }..removeWhere((key, value) => value == null);

    final contribution = Contribution(
      id: '',
      userId: '',
      type: ContributionType.createPlace,
      status: ContributionStatus.pending,
      title: name,
      description: _optional(_description.text),
      payload: payload,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final created =
          await _contributionService.submitContribution(contribution);

      if (!mounted) {
        return;
      }

      if (created == null) {
        setState(() {
          _submitting = false;
          _error = 'تعذر إرسال المساهمة. أعد المحاولة.';
        });
        return;
      }

      navigator.pop(created);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
        _error = 'تعذر إرسال المساهمة. تحقق من اتصالك وأعد المحاولة.';
      });
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  TextEditingController _controllerFor(String fieldKey) {
    switch (fieldKey) {
      case 'category':
        return _category;

      case 'city':
        return _city;

      case 'description':
        return _description;

      case 'phone':
        return _phone;

      case 'website':
        return _website;

      default:
        return _name;
    }
  }
@override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // طبقة التعتيم خلف الورقة — الضغط عليها يغلق النموذج.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop<Contribution?>(null),
                child: const ColoredBox(color: Color(0x33000000)),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius:
                        const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: _buildForm(colors, context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(WaynColors colors, BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'إضافة مكان جديد',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop<Contribution?>(null),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'سيُرسل المكان للمراجعة قبل ظهوره في WAYN.',
          style: TextStyle(fontSize: 12, color: colors.textMuted),
        ),
        const SizedBox(height: 14),
        _field('name', 'اسم المكان', 'مثال: مطعم الأصيل'),
        const SizedBox(height: 10),
        _field('category', 'التصنيف', 'مثال: مطعم'),
        const SizedBox(height: 10),
        _field('city', 'المدينة', 'مثال: طرابلس'),
        const SizedBox(height: 10),
        _field('description', 'الوصف (اختياري)'),
        const SizedBox(height: 10),
        _field('phone', 'الهاتف (اختياري)'),
        const SizedBox(height: 10),
        _field('website', 'الموقع الإلكتروني (اختياري)'),
        const SizedBox(height: 6),
        Text(
          'الموقع: ${widget.latitude.toStringAsFixed(5)}، '
              '${widget.longitude.toStringAsFixed(5)}',
          style: TextStyle(fontSize: 11, color: colors.textMuted),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 12,
              color: colors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _submitting
              ? null
              : () => _submit(context),
          style: FilledButton.styleFrom(
            backgroundColor: colors.brand,
            foregroundColor: colors.onBrand,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          icon: _submitting
              ? const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                )
              : const Icon(Icons.send_rounded, size: 19),
          label: Text(
            _submitting ? 'جارٍ الإرسال للمراجعة…' : 'إرسال للمراجعة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _field(String fieldKey, String label, [String? placeholder]) {
    return TextField(
      controller: _controllerFor(fieldKey),
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: label,
        hintText: placeholder,
      ),
    );
  }
}