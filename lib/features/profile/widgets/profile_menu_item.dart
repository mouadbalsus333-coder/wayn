import 'package:flutter/material.dart';

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onPressed;
  final bool isDestructive;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFE05252)
        : const Color(0xFF263247);

    final iconColor = isDestructive
        ? const Color(0xFFE05252)
        : const Color(0xFF18A99A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFFFF1F1)
                      : const Color(0xFFE8F8F6),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),

                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A94A3),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: isDestructive
                    ? const Color(0xFFE5BABA)
                    : const Color(0xFFB0B7C2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}