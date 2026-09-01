import 'package:flutter/material.dart';

import '../../../core/theme/wayn_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onActionPressed;

  const SectionHeader({
    super.key,
    required this.title,
    required this.action,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),

          const Spacer(),

          TextButton(
            onPressed: onActionPressed,
            child: Text(
              action,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFF18A99A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
