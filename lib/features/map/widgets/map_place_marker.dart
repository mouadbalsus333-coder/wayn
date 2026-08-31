import 'package:flutter/material.dart';

class MapPlaceMarker extends StatelessWidget {
  final String category;
  final bool selected;

  const MapPlaceMarker({
    super.key,
    required this.category,
    this.selected = false,
  });

  IconData get _icon {
    switch (category) {
      case 'مطعم':
        return Icons.restaurant_rounded;

      case 'منتزه':
        return Icons.park_rounded;

      case 'شاطئ':
        return Icons.beach_access_rounded;

      case 'فندق':
        return Icons.hotel_rounded;

      case 'سوق':
        return Icons.shopping_bag_rounded;

      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: selected ? 62 : 56,
            height: selected ? 62 : 56,
            decoration: BoxDecoration(
              color: const Color(0xFF18A99A),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              _icon,
              color: Colors.white,
              size: selected ? 32 : 28,
            ),
          ),

          CustomPaint(
            size: const Size(14, 8),
            painter: _MarkerArrowPainter(),
          ),
        ],
      ),
    );
  }
}

class _MarkerArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF18A99A)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}