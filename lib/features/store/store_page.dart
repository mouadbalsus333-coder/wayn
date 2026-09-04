import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../core/widgets/wayn_network_image.dart';
import '../../features/notifications/notifications_page.dart';
import '../../models/store.dart';
import '../../services/store_service.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  static const _viewModeKey = 'wayn_store_small_view';
  static const _storage = FlutterSecureStorage();

  final _service = StoreService();
  List<StoreCategory> _categories = [];
  List<StoreItem> _items = [];
  List<StoreBanner> _banners = [];
  String? _selectedCategory;
  String? _selectedCurrency;
  final Set<String> _purchasing = {};
  final Map<String, int> _ownedQuantities = {};
  bool _loading = true;
  bool _smallView = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _load();
  }

  Future<void> _loadViewPreference() async {
    try {
      final value = await _storage.read(key: _viewModeKey);
      if (!mounted) return;
      setState(() => _smallView = value == 'small');
    } catch (_) {
      // The default large view remains available if storage is unavailable.
    }
  }

  Future<void> _saveViewPreference(bool small) async {
    setState(() => _smallView = small);
    try {
      await _storage.write(key: _viewModeKey, value: small ? 'small' : 'large');
    } catch (_) {
      // The current selection remains active for this session.
    }
  }

  Future<void> _load() async {
    if (!_loading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

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
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _errorMessage(error);
      });
    }
  }

  List<StoreItem> get _visibleItems => _items
      .where((item) {
        final categoryMatches =
            _selectedCategory == null || item.categoryId == _selectedCategory;
        final currencyMatches =
            _selectedCurrency == null || item.currency == _selectedCurrency;
        return categoryMatches && currencyMatches;
      })
      .toList(growable: false);

  Future<void> _purchase(StoreItem item) async {
    if (_purchasing.contains(item.id)) return;

    setState(() => _purchasing.add(item.id));
    try {
      final purchase = await _service.purchase(item.id);
      if (!mounted) return;
      setState(() {
        _purchasing.remove(item.id);
        _ownedQuantities[item.id] = purchase.ownedQuantity;
      });
      _showMessage(
        purchase.ownedQuantity > 1
            ? 'تم الشراء بنجاح • الكمية المملوكة: ${purchase.ownedQuantity}'
            : 'تم الشراء بنجاح',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _purchasing.remove(item.id));
      _showMessage(_purchaseError(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message, textDirection: TextDirection.rtl),
        ),
      );
  }

  String _purchaseError(Object error) {
    final message = error is ApiClientException
        ? error.message.toLowerCase()
        : error.toString().toLowerCase();

    if (message.contains('insufficient') ||
        message.contains('balance') ||
        message.contains('رصيد')) {
      return 'رصيدك غير كافٍ لشراء هذا المنتج.';
    }
    if (message.contains('inactive') || message.contains('disabled')) {
      return 'هذا المنتج غير متاح حاليًا.';
    }
    if (message.contains('expired')) return 'انتهت مدة توفر هذا المنتج.';
    if (message.contains('not available')) {
      return 'لم يبدأ توفر هذا المنتج بعد.';
    }
    if (message.contains('out of stock')) return 'نفد مخزون هذا المنتج.';
    return 'تعذر إتمام الشراء. حاول مرة أخرى.';
  }

  String _errorMessage(Object error) {
    if (error is ApiClientException) {
      return 'تعذر تحميل المتجر (HTTP ${error.statusCode ?? '؟'}).';
    }
    return 'تعذر تحميل المتجر. تحقق من الاتصال وحاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.waynColors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              WaynHeader(
                onMenuPressed: _onMenuPressed,
                onNotificationsPressed: _onNotificationsPressed,
              ),
              Expanded(child: _buildContent(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(WaynColors colors) {
    if (_loading && _items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: colors.brand));
    }

    if (_loadError != null && _items.isEmpty) {
      return _errorState(colors);
    }

    final visibleItems = _visibleItems;
    return RefreshIndicator(
      color: colors.brand,
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(child: _storeIntro(colors)),
          ),
          if (_banners.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _banner(_banners.first)),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            sliver: SliverToBoxAdapter(child: _currencyFilter(colors)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(child: _categoryFilter(colors)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: _productsHeader(colors, visibleItems.length),
            ),
          ),
          if (visibleItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _emptyState(colors),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _smallView ? 155 : 240,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: _smallView ? .68 : .64,
                ),
                itemCount: visibleItems.length,
                itemBuilder: (context, index) =>
                    _itemCard(colors, visibleItems[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _storeIntro(WaynColors colors) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'متجر WAYN',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'اختر ما يناسب ملفك الشخصي',
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.grid_view_rounded, size: 18),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.apps_rounded, size: 18),
            ),
          ],
          selected: {_smallView},
          onSelectionChanged: (values) => _saveViewPreference(values.first),
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _currencyFilter(WaynColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'العملة',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                colors,
                'الكل',
                null,
                Icons.tune_rounded,
                currency: true,
              ),
              _filterChip(
                colors,
                'Coins',
                'COINS',
                Icons.monetization_on_outlined,
                currency: true,
              ),
              _filterChip(
                colors,
                'Points',
                'POINTS',
                Icons.star_outline_rounded,
                currency: true,
              ),
              _filterChip(
                colors,
                'مجاني',
                'FREE',
                Icons.card_giftcard_outlined,
                currency: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryFilter(WaynColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'التصنيفات',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _filterChip(
                  colors,
                  'الكل',
                  null,
                  Icons.apps_outlined,
                  currency: false,
                );
              }
              final category = _categories[index - 1];
              return _filterChip(
                colors,
                category.nameAr,
                category.id,
                null,
                currency: false,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    WaynColors colors,
    String label,
    String? value,
    IconData? icon, {
    required bool currency,
  }) {
    final selected = currency
        ? _selectedCurrency == value
        : _selectedCategory == value;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 17),
        onSelected: (_) => setState(() {
          if (currency) {
            _selectedCurrency = value;
          } else {
            _selectedCategory = value;
          }
        }),
        selectedColor: colors.brand.withValues(alpha: .16),
        checkmarkColor: colors.brand,
        labelStyle: TextStyle(
          color: selected ? colors.brand : colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _productsHeader(WaynColors colors, int count) {
    return Row(
      children: [
        Text(
          'المنتجات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text('$count', style: TextStyle(color: colors.textMuted)),
      ],
    );
  }

  Widget _banner(StoreBanner banner) {
    final colors = context.waynColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 2.15,
        child: WaynNetworkImage(
          imageUrl: banner.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: colors.surfaceAlt),
        ),
      ),
    );
  }

  Widget _itemCard(WaynColors colors, StoreItem item) {
    final isPurchasing = _purchasing.contains(item.id);
    final ownedQuantity = _ownedQuantities[item.id];
    final image = item.imageUrl == null
        ? Container(
            color: colors.surfaceAlt,
            alignment: Alignment.center,
            child: Icon(
              Icons.storefront_rounded,
              size: _smallView ? 30 : 42,
              color: colors.brand,
            ),
          )
        : WaynNetworkImage(
            imageUrl: item.imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: colors.surfaceAlt,
              alignment: Alignment.center,
              child: Icon(Icons.storefront_rounded, color: colors.brand),
            ),
          );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(_smallView ? 7 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_smallView ? 10 : 14),
                child: SizedBox(width: double.infinity, child: image),
              ),
            ),
            SizedBox(height: _smallView ? 6 : 9),
            Text(
              item.nameAr,
              maxLines: _smallView ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _smallView ? 12 : 14,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _priceLabel(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _smallView ? 11 : 13,
                color: colors.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (ownedQuantity != null) ...[
              const SizedBox(height: 2),
              Text(
                'مملوك: $ownedQuantity',
                style: TextStyle(fontSize: 10, color: colors.textSecondary),
              ),
            ],
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              height: _smallView ? 31 : 36,
              child: FilledButton(
                onPressed: isPurchasing ? null : () => _purchase(item),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: colors.brand,
                ),
                child: isPurchasing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'شراء',
                        style: TextStyle(fontSize: _smallView ? 11 : 12),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceLabel(StoreItem item) {
    if (item.currency == 'FREE') return 'مجاني';
    return '${item.price} ${item.currency}';
  }

  Widget _emptyState(WaynColors colors) {
    final filtered = _selectedCategory != null || _selectedCurrency != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          filtered ? 'لا توجد منتجات تطابق اختيارك' : 'لا توجد منتجات حاليًا',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted),
        ),
      ),
    );
  }

  Widget _errorState(WaynColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuPressed() => showWaynMenu(context);

  void _onNotificationsPressed() => openNotifications(context);
}
