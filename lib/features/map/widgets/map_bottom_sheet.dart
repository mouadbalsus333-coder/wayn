import 'package:flutter/material.dart';

class MapBottomSheet extends StatelessWidget {
  final String placeName;
  final String category;
  final String city;
  final double rating;
  final bool isOpen;
  final VoidCallback? onPressed;

  const MapBottomSheet({
    super.key,
    required this.placeName,
    required this.category,
    required this.city,
    required this.rating,
    required this.isOpen,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F6),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF18A99A),
              size: 29,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placeName,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$category • $city',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8993A3),
                  ),
                ),

                const SizedBox(height: 7),

                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: Color(0xFFFFB52E),
                    ),

                    const SizedBox(width: 3),

                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4E596B),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFE8F8F0)
                            : const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOpen ? 'مفتوح الآن' : 'مغلق',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isOpen
                              ? const Color(0xFF19965E)
                              : const Color(0xFFD95353),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          GestureDetector(
            onTap: onPressed,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF18A99A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }
}