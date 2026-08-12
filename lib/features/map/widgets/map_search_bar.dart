import 'package:flutter/material.dart';

class MapSearchBar extends StatelessWidget {
  final VoidCallback? onFilterPressed;

  const MapSearchBar({
    super.key,
    this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),

          const Icon(
            Icons.search_rounded,
            size: 24,
            color: Color(0xFF7C8798),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'شن تبي تلقى؟',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9AA3B1),
              ),
            ),
          ),

          GestureDetector(
            onTap: onFilterPressed,
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 21,
                color: Color(0xFF18A99A),
              ),
            ),
          ),

          const SizedBox(width: 6),
        ],
      ),
    );
  }
}