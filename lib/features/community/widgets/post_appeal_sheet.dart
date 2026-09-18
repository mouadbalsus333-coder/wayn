import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/theme/wayn_colors.dart';
import '../../../services/repositories/repository_factory.dart';
import '../repositories/community_repository.dart';

/// أنواع الطعن المدعومة حاليًا في الـ backend (قابلة للتوسع).
const appealTypes = <String, String>{
  'INCORRECT_RATING': 'التقييم غير صحيح',
  'MISLEADING_RATING': 'التقييم مضلل',
  'OTHER': 'سبب آخر',
};

/// يفتح sheet الطعن في التقييم لمنشور يخص مستخدمًا آخر.
///
/// يمنع التكرار عبر فحص وجود طعن سابق للمستخدم على نفس المنشور،
/// ويفرض الـ backend نفس القاعدة في الخادم أيضًا.
Future<void> showPostAppealSheet(
  BuildContext context,
  String postId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostAppealSheet(postId: postId),
  );
}

class _PostAppealSheet extends StatefulWidget {
  final String postId;

  const _PostAppealSheet({required this.postId});

  @override
  State<_PostAppealSheet> createState() => _PostAppealSheetState();
}

class _PostAppealSheetState extends State<_PostAppealSheet> {
  final CommunityRepository _repository = createCommunityRepository();

  final TextEditingController _reasonController = TextEditingController();

  String _type = 'INCORRECT_RATING';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String? _validate(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'يرجى كتابة سبب الطعن';
    }

    if (trimmed.length < 10) {
      return 'اشرح المشكلة في 10 أحرف على الأقل';
    }

    if (trimmed.length > 5000) {
      return 'نص الطعن طويل جدًا';
    }

    return null;
  }

  Future<void> _submit() async {
    final error = _validate(_reasonController.text);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final existing = await _repository.getMyAppeal(widget.postId);

      if (existing != null) {
        final status = existing['status']?.toString() ?? '';

        if (status == 'PENDING' || status == 'UNDER_REVIEW') {
          if (!mounted) return;

          setState(() {
            _submitting = false;
            _error = 'لديك طعن قيد المراجعة على هذا المنشور بالفعل';
          });
          return;
        }
      }

      await _repository.submitAppeal(
        widget.postId,
        type: _type,
        reason: _reasonController.text.trim(),
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
              'تم إرسال طعنك، وسيتم إشعارك بنتيجة المراجعة',
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
                      color: colors.brand.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Iconsax.star,
                      color: colors.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الطعن في التقييم',
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
                'إذا رأيت أن التقييم في هذا المنشور غير صحيح، اشرح لنا المشكلة وسيقوم فريق WAYN بمراجعتها.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ...appealTypes.entries.map(
                (entry) => RadioListTile<String>(
                  value: entry.key,
                  groupValue: _type,
                  onChanged: _submitting
                      ? null
                      : (value) =>
                          setState(() => _type = value ?? _type),
                  title: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  activeColor: colors.brand,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _reasonController,
                enabled: !_submitting,
                maxLines: 4,
                maxLength: 5000,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'اشرح سبب الطعن (إلزامي)...',
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
                  backgroundColor: colors.brand,
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
                        'إرسال الطعن',
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
