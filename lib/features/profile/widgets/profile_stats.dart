import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          children: [
            Expanded(
              child: _StatItem(
                value: '0',
                label: 'الزيارات',
                icon: Icons.visibility_outlined,
              ),
            ),
            _StatDivider(),
            Expanded(
              child: _StatItem(
                value: '0',
                label: 'المحفوظات',
                icon: Icons.bookmark_border_rounded,
              ),
            ),
            _StatDivider(),
            Expanded(
              child: _StatItem(
                value: '0',
                label: 'الإعجابات',
                icon: Icons.favorite_border_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 21,
          color: const Color(0xFF18A99A),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF7A8494),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      color: const Color(0xFFE8EBF0),
    );
  }
}