import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final VoidCallback onEditPressed;

  const ProfileHeader({
    super.key,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileIconButton(
                icon: Icons.settings_outlined,
                onPressed: () {},
              ),
              const Spacer(),
              const Text(
                'حسابي',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const Spacer(),
              _ProfileIconButton(
                icon: Icons.notifications_none_rounded,
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 26),

          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE6F8F5),
              border: Border.all(
                color: const Color(0xFF18A99A),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 52,
              color: Color(0xFF18A99A),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'مستخدم وين',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'مرحبًا بك في وين 👋',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF7A8494),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: onEditPressed,
              icon: const Icon(
                Icons.edit_outlined,
                size: 17,
              ),
              label: const Text(
                'تعديل الملف الشخصي',
                textDirection: TextDirection.rtl,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF18A99A),
                side: const BorderSide(
                  color: Color(0xFF18A99A),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ProfileIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
          size: 22,
          color: const Color(0xFF263247),
        ),
      ),
    );
  }
}