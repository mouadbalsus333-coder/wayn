import 'package:flutter/material.dart';

import '../../core/widgets/wayn_header.dart';
import '../../models/store.dart';
import '../../services/store_service.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final _service = StoreService();
  List<StoreCategory> _categories = [];
  List<StoreItem> _items = [];
  List<StoreBanner> _banners = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.categories(),
        _service.items(),
        _service.banners(),
      ]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<StoreCategory>;
        _items = results[1] as List<StoreItem>;
        _banners = results[2] as List<StoreBanner>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<StoreItem> get _visibleItems {
    if (_selectedCategory == null) return _items;
    return _items
        .where((item) => item.categoryId == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed: _onMenuOrNotificationsPressed,
                onNotificationsPressed: _onMenuOrNotificationsPressed,
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                          children: [
                    if (_banners.isNotEmpty) _banner(_banners.first),
                    if (_banners.isNotEmpty) const SizedBox(height: 20),
                    const Text(
                      'الفئات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length + 1,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _categoryTile('الكل', null);
                          }
                          final category = _categories[index - 1];
                          return _categoryTile(
                            category.nameAr,
                            category.id,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المنتجات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_visibleItems.length}',
                          style: const TextStyle(
                            color: Color(0xFF8B94A3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_visibleItems.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(35),
                        child: Center(
                          child: Text('المتجر فارغ حالياً'),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .78,
                        ),
                        itemCount: _visibleItems.length,
                        itemBuilder: (context, index) =>
                            _item(_visibleItems[index]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _onMenuOrNotificationsPressed() {
    debugPrint('Store menu/notifications pressed');
  }

  Widget _banner(StoreBanner banner) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 2.15,
        child: Image.network(
          banner.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFFE5F8F5),
              alignment: Alignment.center,
              child: const Text('WAYN Store'),
            );
          },
        ),
      ),
    );
  }

  Widget _categoryTile(String title, String? id) {
    final selected = _selectedCategory == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = id),
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF18A99A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF18A99A)
                : const Color(0xFFE3E8ED),
          ),
        ),
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : const Color(0xFF30394A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(StoreItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: item.imageUrl == null
                  ? Container(
                      color: const Color(0xFFEAF4F3),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 40,
                        color: Color(0xFF18A99A),
                      ),
                    )
                  : Image.network(
                      item.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFEAF4F3),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF18A99A),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.nameAr,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.price} ${item.currency}',
            style: const TextStyle(
              color: Color(0xFF18A99A),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
