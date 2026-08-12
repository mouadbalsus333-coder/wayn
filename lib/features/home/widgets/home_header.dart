import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;

  const HomeHeader({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.menu_rounded,
            onPressed: onMenuPressed,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'أهلاً بك 👋',
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7A8494),
                        fontWeight: FontWeight.w500,
                      ),
                ),

                const SizedBox(height: 2),

                Text(
                  'وين نروح اليوم؟',
                  textDirection: TextDirection.rtl,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF172033),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),

          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            onPressed: onNotificationsPressed,
            showBadge: true,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool showBadge;

  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: const Color(0xFF263247),
              size: 23,
            ),
          ),

          if (showBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE95353),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF7F9FC),
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}