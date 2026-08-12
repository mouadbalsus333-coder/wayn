import 'package:flutter/material.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _showPlaces = true;
  bool _showRestaurants = false;
  bool _showParks = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F4F6),
        body: Stack(
          children: [
            // =====================================================
            // MAP AREA
            // =====================================================

            Positioned.fill(
              child: _buildMapPlaceholder(),
            ),

            // =====================================================
            // TOP SEARCH
            // =====================================================

            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              left: 16,
              right: 16,
              child: _buildSearchBar(),
            ),

            // =====================================================
            // FILTERS
            // =====================================================

            Positioned(
              top: MediaQuery.of(context).padding.top + 82,
              left: 0,
              right: 0,
              child: _buildFilters(),
            ),

            // =====================================================
            // PLACE MARKERS
            // =====================================================

            if (_showPlaces)
              Positioned(
                top: 245,
                right: 72,
                child: _buildMapMarker(
                  title: 'منتزه طرابلس',
                  icon: Icons.park_rounded,
                ),
              ),

            if (_showRestaurants)
              Positioned(
                top: 390,
                left: 70,
                child: _buildMapMarker(
                  title: 'مطعم مميز',
                  icon: Icons.restaurant_rounded,
                ),
              ),

            if (_showParks)
              Positioned(
                top: 520,
                right: 130,
                child: _buildMapMarker(
                  title: 'منتزه',
                  icon: Icons.park_rounded,
                ),
              ),

            // =====================================================
            // CURRENT LOCATION BUTTON
            // =====================================================

            Positioned(
              left: 18,
              bottom: 125,
              child: _buildLocationButton(),
            ),

            // =====================================================
            // BOTTOM PLACE CARD
            // =====================================================

            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _buildPlacePreview(),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // MAP PLACEHOLDER
  // ===============================================================

  Widget _buildMapPlaceholder() {
    return CustomPaint(
      painter: _MapBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }

  // ===============================================================
  // SEARCH
  // ===============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),

          const Icon(
            Icons.search_rounded,
            size: 24,
            color: Color(0xFF7B8493),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                hintText: 'شن تبي تلقى؟',
                hintStyle: TextStyle(
                  color: Color(0xFF9AA3B1),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),

          Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.only(left: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF16A899),
              size: 21,
            ),
          ),

          const SizedBox(width: 7),
        ],
      ),
    );
  }

  // ===============================================================
  // FILTERS
  // ===============================================================

  Widget _buildFilters() {
    return SizedBox(
      height: 42,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildFilter(
            title: 'كل الأماكن',
            icon: Icons.place_rounded,
            selected: _showPlaces,
            onPressed: () {
              setState(() {
                _showPlaces = !_showPlaces;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildFilter(
            title: 'مطاعم',
            icon: Icons.restaurant_rounded,
            selected: _showRestaurants,
            onPressed: () {
              setState(() {
                _showRestaurants = !_showRestaurants;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildFilter(
            title: 'منتزهات',
            icon: Icons.park_rounded,
            selected: _showParks,
            onPressed: () {
              setState(() {
                _showParks = !_showParks;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildFilter(
            title: 'مفتوح الآن',
            icon: Icons.access_time_rounded,
            selected: false,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilter({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF16A899)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? Colors.white
                  : const Color(0xFF697386),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : const Color(0xFF596273),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // MAP MARKER
  // ===============================================================

  Widget _buildMapMarker({
    required String title,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ),

        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF16A899),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A899)
                    .withValues(alpha: 0.30),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // LOCATION
  // ===============================================================

  Widget _buildLocationButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () {
          debugPrint('Current location pressed');
        },
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.my_location_rounded,
            color: Color(0xFF16A899),
            size: 23,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // PLACE PREVIEW
  // ===============================================================

  Widget _buildPlacePreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              'https://images.unsplash.com/photo-1500534623283-312aade485b7?auto=format&fit=crop&w=300&q=80',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  width: 72,
                  height: 72,
                  color: const Color(0xFFE8F8F6),
                  child: const Icon(
                    Icons.image_rounded,
                    color: Color(0xFF16A899),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'منتزه طرابلس',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'منتزه • طرابلس',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8993A3),
                  ),
                ),

                SizedBox(height: 7),

                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFF5B942),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF596273),
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: Color(0xFF22B573),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'مفتوح الآن',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22B573),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: Color(0xFF9AA3B1),
          ),

          const SizedBox(width: 5),
        ],
      ),
    );
  }
}

// ===================================================================
// SIMPLE MAP BACKGROUND
// ===================================================================

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = const Color(0xFFE9EEF0);

    canvas.drawRect(
      Offset.zero & size,
      backgroundPaint,
    );

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 26
      ..style = PaintingStyle.stroke;

    final roadPaintSmall = Paint()
      ..color = Colors.white
      ..strokeWidth = 13
      ..style = PaintingStyle.stroke;

    final path1 = Path()
      ..moveTo(-50, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.55,
        size.width + 50,
        size.height * 0.66,
      );

    canvas.drawPath(path1, roadPaint);

    final path2 = Path()
      ..moveTo(size.width * 0.15, -50)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.35,
        size.width * 0.30,
        size.height + 50,
      );

    canvas.drawPath(path2, roadPaint);

    final path3 = Path()
      ..moveTo(-20, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.42,
        size.width + 30,
        size.height * 0.20,
      );

    canvas.drawPath(path3, roadPaintSmall);

    final path4 = Path()
      ..moveTo(size.width * 0.72, -20)
      ..quadraticBezierTo(
        size.width * 0.60,
        size.height * 0.45,
        size.width * 0.90,
        size.height + 30,
      );

    canvas.drawPath(path4, roadPaintSmall);

    final blockPaint = Paint()
      ..color = const Color(0xFFDCE5E7);

    for (double x = 20; x < size.width; x += 90) {
      for (double y = 150; y < size.height - 100; y += 85) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 58, 42),
            const Radius.circular(5),
          ),
          blockPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}