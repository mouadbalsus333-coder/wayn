import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/theme/wayn_colors.dart';
import '../../../services/repositories/repository_factory.dart';
import '../repositories/community_repository.dart';

/// تصنيفات البلاغ المدعومة حاليًا في الـ backend (قابلة للتوسع).
const reportCategories = <String, String>{
  'ABUSE': 'سب أو إساءة',
  'INAPPROPRIATE_CONTENT': 'محتوى غير مناسب',
  'SPAM': 'إعلانات / مزعج',
  'FALSE_INFO': 'معلومات خاطئة',
  'OTHER': 'سبب آخر',
};

/// يفتح sheet الإبلاغ عن منشور يخص مستخدمًا آخر.
Future<void> showPostReportSheet(
  BuildContext context,
  String postId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostReportSheet(postId: postId),
  );
}

class _PostReportSheet extends StatefulWidget {
  final String postId;

  const _PostReportSheet({required this.postId});

  @override
  State<_PostReportSheet> createState() => _PostReportSheetState();
}

class _PostReportSheetState extends State<_PostReportSheet> {
  final CommunityRepository _repository = createCommunityRepository();

  final TextEditingController _descriptionController =
      TextEditingController();

  String _category = 'ABUSE';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'يرجى كتابة وصف المشكلة';
    }

    if (trimmed.length < 10) {
      return 'اشرح المشكلة في 10 أحرف على الأقل';
    }

    if (trimmed.length > 5000) {
      return 'نص البلاغ طويل جدًا';
    }

    return null;
  }

  Future<void> _submit() async {
    final error = _validate(_descriptionController.text);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      await _repository.submitReport(
        widget.postId,
        category: _category,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Text(
              'تم إرسال بلاغك، وشكرًا لمساعدتك في الحفاظ على مجتمع WAYN',
              textDirection: TextDirection.rtl,
            ),
          ),
        );

      Navigator.of(context).pop();
    } catch (caught) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _error = caught.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Iconsax.flag,
                      color: colors.danger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الإبلاغ عن المنشور',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'اختر تصنيف البلاغ واشرح المشكلة، وسيقوم فريق WAYN بمراجعة البلاغ.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reportCategories.entries.map((entry) {
                  final selected = _category == entry.key;

                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: _submitting
                        ? null
                        : (value) =>
                            setState(() => _category = entry.key),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? colors.surface
                          : colors.textPrimary,
                    ),
                    selectedColor: colors.brand,
                    backgroundColor: colors.surfaceAlt,
                    side: BorderSide.none,
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                enabled: !_submitting,
                maxLines: 4,
                maxLength: 5000,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'اشرح المشكلة (إلزامي)... مثال: يوجد سب وإساءة في المنشور',
                  counterText: '',
                  filled: true,
                  fillColor: colors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.surface,
                        ),
                      )
                    : const Text(
                        'إرسال البلاغ',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
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
