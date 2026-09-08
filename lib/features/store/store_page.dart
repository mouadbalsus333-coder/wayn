import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/wayn_colors.dart';
import '../../core/widgets/wayn_header.dart';
import '../../core/widgets/wayn_menu_drawer.dart';
import '../../core/widgets/wayn_network_image.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/wallet/wallet_page.dart';
import '../../models/store.dart';
import '../../models/wallet.dart';
import '../../services/store_service.dart';
import '../../services/user_service.dart';
import '../../services/wallet_service.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  static const _viewModeKey = 'wayn_store_small_view';
  static const _storage = FlutterSecureStorage();

  final _service = StoreService();
  final _walletService = WalletService();
  final _userService = UserService();

  final PageController _bannerController = PageController();

  Timer? _bannerTimer;

  List<StoreCategory> _categories = [];
  List<StoreItem> _items = [];
  List<StoreBanner> _banners = [];

  Wallet? _wallet;

  String? _selectedCategory;
  String? _selectedCurrency;

  final Set<String> _purchasing = {};
  final Map<String, int> _ownedQuantities = {};

  bool _loading = true;
  bool _walletLoading = true;
  bool _pointsLoading = true;
  bool _smallView = false;
  String? _loadError;

  int _points = 0;

  int _rotationSeconds = 0;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();

    _loadViewPreference();
    _load();
    _loadWallet();
    _loadPoints();
  }

  @override
  void dispose() {
    _stopBannerTimer();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadViewPreference() async {
    try {
      final value = await _storage.read(key: _viewModeKey);

      if (!mounted) return;

      setState(() {
        _smallView = value == 'small';
      });
    } catch (_) {
      // The default large view remains available if storage is unavailable.
    }
  }

  Future<void> _saveViewPreference(bool small) async {
    if (mounted) {
      setState(() {
        _smallView = small;
      });
    }

    try {
      await _storage.write(
        key: _viewModeKey,
        value: small ? 'small' : 'large',
      );
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
        _service.storeAds(),
      ]);

      if (!mounted) return;

      final storeAds = results[2] as StoreAds;

      _stopBannerTimer();

      setState(() {
        _categories = results[0] as List<StoreCategory>;
        _items = results[1] as List<StoreItem>;
        _banners = storeAds.ads;
        _rotationSeconds = storeAds.rotationSeconds;
        _currentBannerIndex = 0;
        _loading = false;
        _loadError = null;
      });

      _resetBannerPosition();
      _startBannerTimer();
    } catch (error) {
      if (!mounted) return;

      _stopBannerTimer();

      setState(() {
        _loading = false;
        _loadError = _errorMessage(error);
      });
    }
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await _walletService.getWallet();

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _walletLoading = false;
      });
    }
  }

  Future<void> _loadPoints() async {
    try {
      final points = await _userService.getMyPoints();

      if (!mounted) return;

      setState(() {
        _points = points;
        _pointsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _pointsLoading = false;
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

    setState(() {
      _purchasing.add(item.id);
    });

    try {
      final purchase = await _service.purchase(item.id);

      if (!mounted) return;

      setState(() {
        _purchasing.remove(item.id);
        _ownedQuantities[item.id] = purchase.ownedQuantity;
      });

      await Future.wait([
        _loadWallet(),
        _loadPoints(),
      ]);

      _showMessage(
        purchase.ownedQuantity > 1
            ? 'تم الشراء بنجاح • الكمية المملوكة: ${purchase.ownedQuantity}'
            : 'تم الشراء بنجاح',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _purchasing.remove(item.id);
      });

      _showMessage(_purchaseError(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
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

    if (message.contains('expired')) {
      return 'انتهت مدة توفر هذا المنتج.';
    }

    if (message.contains('not available')) {
      return 'لم يبدأ توفر هذا المنتج بعد.';
    }

    if (message.contains('out of stock')) {
      return 'نفد مخزون هذا المنتج.';
    }

    return 'تعذر إتمام الشراء. حاول مرة أخرى.';
  }

  String _errorMessage(Object error) {
    if (error is ApiClientException) {
      return 'تعذر تحميل المتجر (HTTP ${error.statusCode ?? '؟'}).';
    }

    return 'تعذر تحميل المتجر. تحقق من الاتصال وحاول مرة أخرى.';
  }

  // ---------------------------------------------------------------------------
  // Banner autoplay
  // ---------------------------------------------------------------------------

  void _stopBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
  }

  void _startBannerTimer() {
    _stopBannerTimer();

    if (!mounted) return;
    if (_banners.length <= 1) return;
    if (_rotationSeconds <= 0) return;

    _bannerTimer = Timer(
      Duration(seconds: _rotationSeconds),
      _advanceBanner,
    );
  }

  void _resetBannerTimer() {
    _startBannerTimer();
  }

  Future<void> _advanceBanner() async {
    if (!mounted || _banners.length <= 1) {
      _stopBannerTimer();
      return;
    }

    final nextIndex = (_currentBannerIndex + 1) % _banners.length;

    _currentBannerIndex = nextIndex;

    if (_bannerController.hasClients) {
      await _bannerController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }

    if (!mounted) return;

    _startBannerTimer();
  }

  void _onBannerPageChanged(int index) {
    _currentBannerIndex = index;

    _resetBannerTimer();
  }

  void _resetBannerPosition() {
    if (!_bannerController.hasClients) return;

    final targetIndex = _banners.isEmpty
        ? 0
        : _currentBannerIndex.clamp(0, _banners.length - 1);

    _bannerController.jumpToPage(targetIndex);
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
              Expanded(
                child: _buildContent(colors),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(WaynColors colors) {
    if (_loading && _items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.brand,
        ),
      );
    }

    if (_loadError != null && _items.isEmpty) {
      return _errorState(colors);
    }

    final visibleItems = _visibleItems;

    return RefreshIndicator(
      color: colors.brand,
      onRefresh: () async {
        await Future.wait([
          _load(),
          _loadWallet(),
          _loadPoints(),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _storeIntro(colors),
            ),
          ),
          if (_banners.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _bannerCarousel(colors),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            sliver: SliverToBoxAdapter(
              child: _productsHeader(
                colors,
                visibleItems.length,
              ),
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
                  maxCrossAxisExtent: _smallView ? 180 : 260,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: _smallView ? .66 : .72,
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
        _buildWalletButton(colors),
        const SizedBox(width: 8),
        _buildPointsButton(colors),
        const Spacer(),
        _buildStoreOptionsButton(colors),
      ],
    );
  }

  Widget _buildWalletButton(WaynColors colors) {
    final coins = _wallet?.coinsBalance ?? 0;

    return _buildHeaderActionButton(
      colors,
      icon: Icons.account_balance_wallet_rounded,
      iconColor: colors.brand,
      iconBackground: colors.brand.withValues(alpha: .12),
      value: _walletLoading ? null : '$coins',
      loading: _walletLoading,
      onTap: _openWallet,
    );
  }

  Widget _buildPointsButton(WaynColors colors) {
    return _buildHeaderActionButton(
      colors,
      icon: Icons.stars_rounded,
      iconColor: Colors.orange,
      iconBackground: Colors.orange.withValues(alpha: .12),
      value: _pointsLoading ? null : '$_points',
      loading: _pointsLoading,
      onTap: () {
        // Points are displayed from the authenticated user's real balance.
      },
    );
  }

  Widget _buildHeaderActionButton(
    WaynColors colors, {
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required VoidCallback onTap,
    String? value,
    bool loading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 46,
          constraints: const BoxConstraints(
            minWidth: 46,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: colors.divider,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 3),
                color: Colors.black.withValues(alpha: .04),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 7),
              if (loading)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              else if (value != null)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWallet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WalletPage(),
      ),
    );
  }

  Widget _buildStoreOptionsButton(WaynColors colors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showStoreOptions,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: colors.divider,
            ),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: colors.textPrimary,
            size: 21,
          ),
        ),
      ),
    );
  }

  void _showStoreOptions() {
    final colors = context.waynColors;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colors.background,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void refreshSheet() {
              if (sheetContext.mounted) {
                setSheetState(() {});
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'خيارات المتجر',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'حجم المنتجات',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _viewModeOption(
                                colors,
                                label: 'كبير',
                                icon: Icons.grid_view_rounded,
                                selected: !_smallView,
                                onTap: () {
                                  _saveViewPreference(false);
                                  refreshSheet();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _viewModeOption(
                                colors,
                                label: 'صغير',
                                icon: Icons.apps_rounded,
                                selected: _smallView,
                                onTap: () {
                                  _saveViewPreference(true);
                                  refreshSheet();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'العملة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _filterChip(
                              colors,
                              'الكل',
                              null,
                              Icons.tune_rounded,
                              currency: true,
                              onChanged: refreshSheet,
                            ),
                            _filterChip(
                              colors,
                              'Coins',
                              'COINS',
                              Icons.monetization_on_outlined,
                              currency: true,
                              onChanged: refreshSheet,
                            ),
                            _filterChip(
                              colors,
                              'Points',
                              'POINTS',
                              Icons.star_outline_rounded,
                              currency: true,
                              onChanged: refreshSheet,
                            ),
                            _filterChip(
                              colors,
                              'مجاني',
                              'FREE',
                              Icons.card_giftcard_outlined,
                              currency: true,
                              onChanged: refreshSheet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'التصنيفات',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _filterChip(
                              colors,
                              'الكل',
                              null,
                              Icons.apps_outlined,
                              currency: false,
                              onChanged: refreshSheet,
                            ),
                            ..._categories.map(
                              (category) => _filterChip(
                                colors,
                                category.nameAr,
                                category.id,
                                null,
                                currency: false,
                                onChanged: refreshSheet,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _viewModeOption(
    WaynColors colors, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? colors.brand.withValues(alpha: .12)
              : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.brand
                : colors.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 19,
              color: selected
                  ? colors.brand
                  : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected
                    ? colors.brand
                    : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    WaynColors colors,
    String label,
    String? value,
    IconData? icon, {
    required bool currency,
    VoidCallback? onChanged,
  }) {
    final selected = currency
        ? _selectedCurrency == value
        : _selectedCategory == value;

    return FilterChip(
      selected: selected,
      label: Text(label),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 17,
            ),
      onSelected: (_) {
        setState(() {
          if (currency) {
            _selectedCurrency = value;
          } else {
            _selectedCategory = value;
          }
        });

        onChanged?.call();
      },
      selectedColor: colors.brand.withValues(alpha: .16),
      checkmarkColor: colors.brand,
      labelStyle: TextStyle(
        color: selected
            ? colors.brand
            : colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _bannerCarousel(WaynColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 2.15,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              physics: const BouncingScrollPhysics(),
              pageSnapping: true,
              onPageChanged: _onBannerPageChanged,
              itemBuilder: (context, index) {
                return _banner(
                  colors,
                  _banners[index],
                );
              },
            ),
          ),
        ),
        if (_banners.length > 1) ...[
          const SizedBox(height: 10),
          _bannerIndicator(colors),
        ],
      ],
    );
  }

  Widget _bannerIndicator(WaynColors colors) {
    return AnimatedBuilder(
      animation: _bannerController,
      builder: (context, child) {
        var currentPage = _currentBannerIndex.toDouble();

        if (_bannerController.hasClients &&
            _bannerController.page != null) {
          currentPage = _bannerController.page!;
        }

        final currentIndex = currentPage.round();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (index) {
              final selected = index == currentIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.brand
                      : colors.divider,
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _banner(
    WaynColors colors,
    StoreBanner banner,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openBannerLink(banner),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              banner.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: colors.surfaceAlt,
                );
              },
            ),
            if (banner.targetUrl != null &&
                banner.targetUrl!.trim().isNotEmpty)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBannerLink(StoreBanner banner) async {
    final rawUrl = banner.targetUrl?.trim();

    if (rawUrl == null || rawUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(rawUrl);

    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _showMessage('رابط الإعلان غير صالح.');
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage('تعذر فتح رابط الإعلان.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر فتح رابط الإعلان.');
      }
    }
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
        Text(
          '$count',
          style: TextStyle(
            color: colors.textMuted,
          ),
        ),
      ],
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
            height: double.infinity,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: colors.surfaceAlt,
                alignment: Alignment.center,
                child: Icon(
                  Icons.storefront_rounded,
                  color: colors.brand,
                ),
              );
            },
          );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(
          _smallView ? 8 : 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  _smallView ? 10 : 14,
                ),
                child: SizedBox.expand(
                  child: image,
                ),
              ),
            ),
            SizedBox(
              height: _smallView ? 7 : 9,
            ),
            Text(
              item.nameAr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: _smallView ? 12 : 14,
                height: 1.25,
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
                style: TextStyle(
                  fontSize: 10,
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 7),
            SizedBox(
              width: double.infinity,
              height: _smallView ? 31 : 36,
              child: FilledButton(
                onPressed:
                    isPurchasing ? null : () => _purchase(item),
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
                        style: TextStyle(
                          fontSize: _smallView ? 11 : 12,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _priceLabel(StoreItem item) {
    if (item.currency == 'FREE') {
      return 'مجاني';
    }

    return '${item.price} ${item.currency}';
  }

  Widget _emptyState(WaynColors colors) {
    final filtered =
        _selectedCategory != null || _selectedCurrency != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          filtered
              ? 'لا توجد منتجات تطابق اختيارك'
              : 'لا توجد منتجات حاليًا',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textMuted,
          ),
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
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: colors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
              ),
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

  void _onMenuPressed() {
    showWaynMenu(context);
  }

  void _onNotificationsPressed() {
    openNotifications(context);
  }
}