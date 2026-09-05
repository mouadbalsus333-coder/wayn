import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/wayn_api.dart';
import '../../../models/contribution.dart';
import '../../../core/widgets/wayn_network_image.dart';
import '../manage/admin_manage_page.dart';
import '../store/admin_store_dialogs.dart';
import '../store/admin_store_models.dart';
import '../store/admin_store_service.dart';

import '../wallet/admin_wallet_recharge_page.dart';
import 'place_edit_screen.dart';

const _storeBrandColor = Color(0xFF18A99A);
const _storeMutedColor = Color(0xFF8B94A3);

/// Real WAYN admin dashboard.
///
/// Each section loads from the FastAPI backend independently, so a failure in
/// one endpoint never blanks the whole panel. HTTP errors are surfaced instead
/// of being silently swallowed.
class AdminDashboardPage extends StatefulWidget {
  final String adminName;

  /// Resolved permission names the current admin is allowed to use.
  /// Drives which sections are shown (in addition to the backend guards).
  final List<String> permissions;

  /// Human-facing role label: ``super_admin`` or ``admin`` (or empty).
  final String role;

  const AdminDashboardPage({
    super.key,
    required this.adminName,
    this.permissions = const [],
    this.role = '',
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

/// A dashboard section definition used to build the dynamic tab bar.
class _AdminSection {
  final String id;
  final String label;
  final bool superAdminOnly;
  final List<String> permissions;
  final Widget Function() body;

  const _AdminSection({
    required this.id,
    required this.label,
    this.superAdminOnly = false,
    this.permissions = const [],
    required this.body,
  });
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Visible sections, filtered by the current admin role/permissions.
  late final List<_AdminSection> _sections;

  bool _initialLoading = true;

  // Admin users (/api/v1/admin/users)
  List<dynamic> _users = [];
  String? _usersError;

  // Places (public /api/v1/places returns {items, total, page, limit, pages})
  List<dynamic> _places = [];
  String? _placesError;

  // Contributions (/api/v1/admin/contributions returns {items, total, ...})
  List<dynamic> _contributions = [];
  String? _contributionsError;

  // Store items (/api/v1/store/items)
  final _storeService = AdminStoreService();
  List<AdminStoreItem> _storeItems = [];
  List<AdminStoreCategory> _storeCategories = [];
  String? _storeError;

  // Permissions (/api/v1/admin/permissions)
  List<dynamic> _permissions = [];
  String? _permissionsError;

  @override
  void initState() {
    super.initState();
    _sections = _buildSections();
    _tabController = TabController(length: _sections.length, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ================================================================
  // Independent loading
  // ================================================================

  Future<void> _loadAll() async {
    setState(() => _initialLoading = true);

    final futures = <Future<void>>[];

    if (_hasSection('admins')) futures.add(_loadUsers());
    if (_hasSection('places')) futures.add(_loadPlaces());
    if (_hasSection('contributions')) futures.add(_loadContributions());
    if (_hasSection('store')) futures.add(_loadStore());
    if (_hasSection('permissions')) futures.add(_loadPermissions());

    await Future.wait(futures);

    if (!mounted) return;
    setState(() => _initialLoading = false);
  }

  bool get _hasLoading => _initialLoading;

  // ================================================================
  // Permission-aware sections
  // ================================================================

  bool get _isSuperAdmin => widget.role == 'super_admin';

  bool _hasPermission(String name) {
    return widget.permissions.contains(name);
  }

  bool _hasAnyPermission(List<String> names) {
    for (final name in names) {
      if (widget.permissions.contains(name)) return true;
    }
    return false;
  }

  bool _hasSection(String id) {
    for (final section in _sections) {
      if (section.id == id) return true;
    }
    return false;
  }

  int _indexOfSection(String id) {
    for (var i = 0; i < _sections.length; i++) {
      if (_sections[i].id == id) return i;
    }
    return 0;
  }

  List<_AdminSection> _buildSections() {
    final sections = <_AdminSection>[];

    sections.add(_AdminSection(
      id: 'overview',
      label: 'الرئيسية',
      body: _overviewSection,
    ));

    if (_isSuperAdmin) {
      sections.add(_AdminSection(
        id: 'admins',
        label: 'إدارة المشرفين',
        superAdminOnly: true,
        body: _usersSection,
      ));
    }

    if (_hasAnyPermission(const ['places.read', 'places.write'])) {
      sections.add(_AdminSection(
        id: 'places',
        label: 'الأماكن',
        permissions: const ['places.read', 'places.write'],
        body: _placesSection,
      ));
    }

    if (_hasPermission('contributions.read')) {
      sections.add(_AdminSection(
        id: 'contributions',
        label: 'المساهمات',
        permissions: const ['contributions.read'],
        body: _contributionsSection,
      ));
    }

    if (_hasAnyPermission(const ['store.read', 'store.write'])) {
      sections.add(_AdminSection(
        id: 'store',
        label: 'المتجر',
        permissions: const ['store.read', 'store.write'],
        body: _storeSection,
      ));
    }

    if (_isSuperAdmin) {
      sections.add(_AdminSection(
        id: 'permissions',
        label: 'الصلاحيات',
        superAdminOnly: true,
        body: _permissionsSection,
      ));
    }

    if (_hasAnyPermission(const [
      'wallet.read',
      'wallet.recharge',
      'wallet.adjust',
      'wallet.transactions',
    ])) {
      sections.add(_AdminSection(
        id: 'wallet',
        label: 'المحافظ',
        permissions: const [
          'wallet.read',
          'wallet.recharge',
          'wallet.adjust',
          'wallet.transactions',
        ],
        body: () => const AdminWalletRechargePage(),
      ));
    }

    return sections;
  }

  Future<List<dynamic>> _readList(Future<dynamic> call) async {
    final result = await call;

    if (result is List) {
      return List<dynamic>.from(result);
    }

    if (result is Map) {
      final items = result['items'];

      if (items is List) {
        return List<dynamic>.from(items);
      }
    }

    throw ApiClientException('تجاوب غير متوقع من الخادم (متوقع قائمة بيانات).');
  }

  void _setError(void Function(String error) apply, {required Object error}) {
    final message = switch (error) {
      ApiClientException api =>
        'HTTP ${api.statusCode ?? '؟'} — ${api.message}',
      _ => '$error',
    };
    apply(message);
  }

  String _errorMessage(Object error) {
    if (error is ApiClientException) {
      return 'HTTP ${error.statusCode ?? '؟'} — ${error.message}';
    }
    return '$error';
  }

  Future<void> _loadUsers() async {
    setState(() => _usersError = null);

    try {
      final list = await _readList(waynAdminApi.get('/api/v1/admin/users'));
      if (!mounted) return;
      setState(() => _users = list);
    } catch (error) {
      if (!mounted) return;
      _setError(
        (m) => setState(() => _usersError = 'تعذر تحميل المستخدمين ($m)'),
        error: error,
      );
    }
  }

  Future<void> _loadPlaces() async {
    setState(() => _placesError = null);

    try {
      final response = await waynAdminApi.get(
        '/api/v1/places',
        queryParams: {'page': 1, 'limit': 100},
      );
      final data = response is Map ? response : <String, dynamic>{};
      final items = data['items'];

      if (!mounted) return;
      setState(() {
        _places = items is List ? List<dynamic>.from(items) : [];
      });
    } catch (error) {
      if (!mounted) return;
      _setError(
        (m) => setState(() => _placesError = 'تعذر تحميل الأماكن ($m)'),
        error: error,
      );
    }
  }

  Future<void> _loadContributions() async {
    setState(() => _contributionsError = null);

    try {
      final response = await waynAdminApi.get(
        '/api/v1/admin/contributions',
        queryParams: {'offset': 0, 'limit': 100},
      );
      final data = response is Map ? response : <String, dynamic>{};
      final items = data['items'];

      if (!mounted) return;
      setState(() {
        _contributions = items is List ? List<dynamic>.from(items) : [];
      });
    } catch (error) {
      if (!mounted) return;
      _setError(
        (m) =>
            setState(() => _contributionsError = 'تعذر تحميل المساهمات ($m)'),
        error: error,
      );
    }
  }

  Future<void> _loadStore() async {
    setState(() => _storeError = null);

    try {
      final results = await Future.wait([
        _storeService.getItems(),
        _storeService.getCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _storeItems = results[0] as List<AdminStoreItem>;
        _storeCategories = results[1] as List<AdminStoreCategory>;
      });
    } catch (error) {
      if (!mounted) return;
      _setError(
        (m) => setState(() => _storeError = 'تعذر تحميل عناصر المتجر ($m)'),
        error: error,
      );
    }
  }

  Future<void> _createCategory() async {
    final saved = await showAdminStoreCategoryEditor(
      context,
      onSave: _storeService.createCategory,
    );
    if (saved == true && mounted) await _loadStore();
  }

  Future<void> _editCategory(AdminStoreCategory category) async {
    final saved = await showAdminStoreCategoryEditor(
      context,
      category: category,
      onSave: (body) => _storeService.updateCategory(category.id, body),
    );
    if (saved == true && mounted) await _loadStore();
  }

  Future<void> _toggleCategory(AdminStoreCategory category) async {
    await _runStoreAction(
      () => _storeService.updateCategory(category.id, {
        'is_active': !category.isActive,
      }),
      successMessage: 'تم تحديث حالة التصنيف.',
    );
  }

  Future<void> _createStoreItem() async {
    if (_storeCategories.isEmpty) {
      _showSnack('أضف تصنيفًا واحدًا على الأقل قبل إنشاء عنصر.');
      return;
    }
    final saved = await showAdminStoreItemEditor(
      context,
      categories: _storeCategories,
      onSave: _storeService.createItem,
      onUploadImage: _storeService.uploadImage,
    );
    if (saved == true && mounted) await _loadStore();
  }

  Future<void> _editStoreItem(AdminStoreItem item) async {
    final saved = await showAdminStoreItemEditor(
      context,
      item: item,
      categories: _storeCategories,
      onSave: (body) => _storeService.updateItem(item.id, body),
      onUploadImage: _storeService.uploadImage,
    );
    if (saved == true && mounted) await _loadStore();
  }

  Future<void> _toggleStoreItem(AdminStoreItem item) async {
    await _runStoreAction(
      () => _storeService.updateItem(item.id, {'is_active': !item.isActive}),
      successMessage: 'تم تحديث حالة العنصر.',
    );
  }

  Future<void> _runStoreAction(
    Future<dynamic> Function() request, {
    required String successMessage,
  }) async {
    try {
      await request();
      await _loadStore();
      if (mounted) _showSnack(successMessage);
    } catch (error) {
      if (mounted) _showSnack('فشل تنفيذ العملية (${_errorMessage(error)})');
    }
  }

  Future<void> _loadPermissions() async {
    setState(() => _permissionsError = null);

    try {
      final list = await _readList(
        waynAdminApi.get('/api/v1/admin/permissions'),
      );
      if (!mounted) return;
      setState(() => _permissions = list);
    } catch (error) {
      if (!mounted) return;
      _setError(
        (m) => setState(() => _permissionsError = 'تعذر تحميل الصلاحيات ($m)'),
        error: error,
      );
    }
  }

  // ================================================================
  // Contribution actions
  // ================================================================

  Future<void> _approveContribution(Map<String, dynamic> contribution) async {
    final id = contribution['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await _confirmAction(
      title: 'اعتماد المساهمة',
      message: 'هل أنت متأكد من اعتماد هذه المساهمة؟',
    );
    if (confirmed != true || !mounted) return;

    await _runAction(
      () => waynAdminApi.post(
        '/api/v1/admin/contributions/$id/approve',
        body: {'points': 0},
      ),
      successMessage: 'تم اعتماد المساهمة.',
    );
  }

  Future<void> _rejectContribution(Map<String, dynamic> contribution) async {
    final id = contribution['id']?.toString();
    if (id == null || id.isEmpty) return;

    final reason = await _askRejectionReason();
    if (reason == null) return;

    if (reason.trim().isEmpty) {
      if (mounted) _showSnack('يرجى كتابة سبب الرفض.');
      return;
    }

    await _runAction(
      () => waynAdminApi.post(
        '/api/v1/admin/contributions/$id/reject',
        body: {'rejection_reason': reason.trim()},
      ),
      successMessage: 'تم رفض المساهمة.',
    );
  }

  Future<void> _runAction(
    Future<dynamic> Function() request, {
    required String successMessage,
  }) async {
    try {
      if (!mounted) return;
      await request();
      await _loadContributions();
      if (mounted) _showSnack(successMessage);
    } catch (error) {
      if (!mounted) return;
      final msg = error is ApiClientException
          ? 'HTTP ${error.statusCode ?? '؟'} — ${error.message}'
          : '$error';
      _showSnack('فشل تنفيذ العملية ($msg)');
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF18A99A),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askRejectionReason() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض المساهمة'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض',
              hintText: 'اكتب سبب رفض المساهمة',
            ),
            minLines: 2,
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD95757),
              ),
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await waynAdminApi.clearAuthToken();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ================================================================
  // Labels
  // ================================================================

  String _statusLabel(ContributionStatus status) {
    switch (status) {
      case ContributionStatus.pending:
        return 'قيد المراجعة';
      case ContributionStatus.approved:
        return 'معتمدة';
      case ContributionStatus.rejected:
        return 'مرفوضة';
      case ContributionStatus.cancelled:
        return 'ملغاة';
    }
  }

  String _typeLabel(ContributionType type) {
    switch (type) {
      case ContributionType.createPlace:
        return 'إضافة مكان';
      case ContributionType.updatePlace:
        return 'تعديل مكان';
      case ContributionType.addImage:
        return 'إضافة صورة';
      case ContributionType.updateInformation:
        return 'تحديث معلومات';
      case ContributionType.verifyPlace:
        return 'التحقق من مكان';
    }
  }

  Widget _sectionBody({
    required bool loading,
    required bool hasData,
    required String empty,
    String? error,
    required Widget child,
  }) {
    if (loading && !hasData) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (error != null && !hasData) {
      return _errorView(error);
    }

    if (!hasData) {
      return _emptyView(empty);
    }

    return child;
  }

  Widget _errorView(String message) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Color(0xFFD95757)),
                  SizedBox(width: 8),
                  Text(
                    'حدث خطأ أثناء تحميل البيانات',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD95757),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: Color(0xFF596273))),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF18A99A),
                ),
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyView(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              color: Color(0xFF8B94A3),
              size: 46,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7A8494)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String title,
    required int count,
    required IconData icon,
    required String sectionId,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _goToTab(_indexOfSection(sectionId)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF18A99A)),
              const SizedBox(height: 5),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Color(0xFF7A8494)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToTab(int index) {
    _tabController.index = index;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _overviewSection() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'نظرة عامة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (_hasSection('admins'))
              _statTile(
                title: 'مشرفون',
                count: _users.length,
                icon: Icons.people_rounded,
                sectionId: 'admins',
              ),
            if (_hasSection('places'))
              _statTile(
                title: 'أماكن',
                count: _places.length,
                icon: Icons.place_rounded,
                sectionId: 'places',
              ),
            if (_hasSection('contributions'))
              _statTile(
                title: 'مساهمات',
                count: _contributions.length,
                icon: Icons.rate_review_rounded,
                sectionId: 'contributions',
              ),
          ],
        ),
        if (_hasSection('store') ||
            _hasSection('permissions') ||
            _hasSection('wallet'))
          ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_hasSection('store'))
                  _statTile(
                    title: 'عناصر المتجر',
                    count: _storeItems.length,
                    icon: Icons.storefront_rounded,
                    sectionId: 'store',
                  ),
                if (_hasSection('permissions'))
                  _statTile(
                    title: 'صلاحيات',
                    count: _permissions.length,
                    icon: Icons.security_rounded,
                    sectionId: 'permissions',
                  ),
                if (_hasSection('wallet'))
                  _statTile(
                    title: 'محافظ',
                    count: 0,
                    icon: Icons.add_card_rounded,
                    sectionId: 'wallet',
                  ),
              ],
            ),
          ],
        const SizedBox(height: 20),
        const Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'لوحة الإدارة تجلب بياناتها مباشرة من خادم FastAPI، وكل قسم يُحمّل بشكل مستقل '
              'بحيث لا يعطّل فشل أحد الأقسام بقية اللوحة. تظهر أخطاء HTTP بوضوح لكل قسم.',
              style: TextStyle(color: Color(0xFF596273)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openAdminManage() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminManagePage(
          onChanged: _loadUsers,
        ),
      ),
    );
  }

  Widget _usersSection() {
    return _sectionBody(
      loading: _hasLoading,
      hasData: _users.isNotEmpty,
      empty: 'لا يوجد مشرفون بعد.',
      error: _usersError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'إدارة المشرفين (${_users.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF18A99A),
                  ),
                  onPressed: _openAdminManage,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('إضافة مشرف'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(18),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = Map<String, dynamic>.from(_users[index] as Map);
          final roles = user['roles'];
          final roleText = roles is List ? roles.join(' • ') : '';

          return Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F8F6),
                child: Icon(Icons.person, color: Color(0xFF18A99A)),
              ),
              title: Text(
                user['full_name']?.toString() ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${user['email'] ?? ''}\n$roleText'),
              isThreeLine: true,
              trailing: Icon(
                user['is_active'] == true
                    ? Icons.check_circle_rounded
                    : Icons.block,
                color: user['is_active'] == true
                    ? const Color(0xFF18A99A)
                    : const Color(0xFFD95757),
              ),
            ),
          );
        },
              ),
            ),
        ],
      ),
    );
  }

  Widget _placesSection() {
    if (_initialLoading && _places.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (_placesError != null && _places.isEmpty) {
      return _placesErrorBody(_placesError!);
    }

    if (_places.isEmpty) {
      return _placesEmptyBody();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'الأماكن (${_places.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF18A99A),
              ),
              onPressed: _openAddPlace,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('إضافة مكان'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final place in _places)
          _placeCard(Map<String, dynamic>.from(place as Map)),
      ],
    );
  }

  Widget _placesErrorBody(String message) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Color(0xFFD95757)),
                  SizedBox(width: 8),
                  Text(
                    'حدث خطأ أثناء تحميل الأماكن',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD95757),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: Color(0xFF596273))),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF18A99A),
                ),
                onPressed: _loadPlaces,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placesEmptyBody() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_outlined,
              color: Color(0xFF8B94A3),
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد أماكن بعد',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF596273),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ابدأ بإضافة أول مكان إلى لوحة إدارة WAYN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7A8494)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF18A99A),
              ),
              onPressed: _openAddPlace,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مكان'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeCard(Map<String, dynamic> place) {
    final name = place['name']?.toString() ?? '—';
    final city = place['city']?.toString() ?? '';
    final category = place['category_name']?.toString() ?? '';
    final imageUrl = place['image_url']?.toString();
    final rating = (place['rating'] as num?)?.toDouble() ?? 0.0;
    final isOpen = place['is_open'] == true;
    final isActive = place['is_active'] == true;
    final verification = place['verification_status']?.toString();
    final visits = (place['visits_count'] as num?)?.toInt() ?? 0;
    final reviews = (place['reviews_count'] as num?)?.toInt() ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: (imageUrl == null || imageUrl.trim().isEmpty)
                    ? Container(
                        color: const Color(0xFFE8F8F6),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Color(0xFF18A99A),
                        ),
                      )
                    : WaynNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          color: const Color(0xFFE8F8F6),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFF18A99A),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBF1DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$rating ★',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB07C00),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [city, category]
                        .whereType<String>()
                        .where((e) => e.isNotEmpty)
                        .join(' • '),
                    style: const TextStyle(
                      color: Color(0xFF7A8494),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _placeChip(
                        isOpen ? 'مفتوح' : 'مغلق',
                        isOpen
                            ? const Color(0xFF18A99A)
                            : const Color(0xFF596273),
                        isOpen
                            ? const Color(0xFFE8F8F6)
                            : const Color(0xFFECEEF2),
                      ),
                      _placeChip(
                        isActive ? 'مفعّل' : 'غير مفعّل',
                        isActive
                            ? const Color(0xFF18A99A)
                            : const Color(0xFFD95757),
                        isActive
                            ? const Color(0xFFE8F8F6)
                            : const Color(0xFFFFECEC),
                      ),
                      if (verification != null && verification.isNotEmpty)
                        _placeChip(
                          _verificationLabel(verification),
                          const Color(0xFF7B61D9),
                          const Color(0xFFF0ECFB),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 15,
                        color: Color(0xFF8B94A3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$visits',
                        style: const TextStyle(
                          color: Color(0xFF7A8494),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.rate_review_outlined,
                        size: 15,
                        color: Color(0xFF8B94A3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$reviews',
                        style: const TextStyle(
                          color: Color(0xFF7A8494),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: 'تعديل',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openEditPlace(place),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF18A99A),
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deletePlace(place),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFD95757),
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  String _verificationLabel(String value) {
    switch (value) {
      case 'verified':
        return 'موثق';
      case 'pending':
        return 'قيد المراجعة';
      case 'unverified':
      case 'not_verified':
        return 'غير موثق';
      default:
        return value;
    }
  }

  // ================================================================
  // Place actions
  // ================================================================

  Future<void> _openAddPlace() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminPlaceEditScreen()),
    );
    if (changed == true && mounted) {
      await _loadPlaces();
      if (mounted) _showSnack('تمت إضافة المكان بنجاح.');
    }
  }

  Future<void> _openEditPlace(Map<String, dynamic> place) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminPlaceEditScreen(place: place)),
    );
    if (changed == true && mounted) {
      await _loadPlaces();
      if (mounted) _showSnack('تم تحديث المكان بنجاح.');
    }
  }

  Future<void> _deletePlace(Map<String, dynamic> place) async {
    final name = place['name']?.toString() ?? 'المكان';
    final id = place['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmed = await _confirmAction(
      title: 'حذف المكان',
      message: 'هل أنت متأكد من حذف "$name"؟ لا يمكن التراجع عن هذه العملية.',
    );
    if (confirmed != true || !mounted) return;

    try {
      await waynAdminApi.delete('/api/v1/admin/places/$id');
      await _loadPlaces();
      if (!mounted) return;
      _showSnack('تم حذف المكان.');
    } catch (error) {
      if (!mounted) return;
      final msg = error is ApiClientException
          ? 'HTTP ${error.statusCode ?? '؟'} — ${error.message}'
          : '$error';
      _showSnack('فشل حذف المكان ($msg)');
    }
  }

  Widget _contributionsSection() {
    return _sectionBody(
      loading: _hasLoading,
      hasData: _contributions.isNotEmpty,
      empty: 'لا توجد مساهمات.',
      error: _contributionsError,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _contributions.length,
        itemBuilder: (context, index) {
          final map = Map<String, dynamic>.from(_contributions[index] as Map);
          final contribution = Contribution.fromMap(map);
          final pending = contribution.status == ContributionStatus.pending;

          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contribution.title.isEmpty
                              ? _typeLabel(contribution.type)
                              : contribution.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _statusChip(contribution.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _typeLabel(contribution.type),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8494),
                    ),
                  ),
                  if (contribution.description != null &&
                      contribution.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      contribution.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(contribution.createdAt) +
                        (contribution.placeId != null
                            ? '  •  #${contribution.placeId}'
                            : ''),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8B94A3),
                    ),
                  ),
                  if (pending) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF18A99A),
                          ),
                          onPressed: () => _approveContribution(map),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('اعتماد'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD95757),
                          ),
                          onPressed: () => _rejectContribution(map),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('رفض'),
                        ),
                      ],
                    ),
                  ],
                  if (contribution.rejectionReason != null &&
                      contribution.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'سبب الرفض: ${contribution.rejectionReason}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD95757),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(ContributionStatus status) {
    final color = switch (status) {
      ContributionStatus.pending => const Color(0xFFB07C00),
      ContributionStatus.approved => const Color(0xFF18A99A),
      ContributionStatus.rejected => const Color(0xFFD95757),
      ContributionStatus.cancelled => const Color(0xFF596273),
    };
    final background = switch (status) {
      ContributionStatus.pending => const Color(0xFFFBF1DB),
      ContributionStatus.approved => const Color(0xFFE8F8F6),
      ContributionStatus.rejected => const Color(0xFFFFECEC),
      ContributionStatus.cancelled => const Color(0xFFECEEF2),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _storeSection() {
    if (_hasLoading && _storeItems.isEmpty && _storeCategories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (_storeError != null) _storeErrorCard(_storeError!),
        Row(
          children: [
            const Text(
              'التصنيفات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _storeBrandColor),
              onPressed: _createCategory,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة تصنيف'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_storeCategories.isEmpty)
          const Text('لا توجد تصنيفات.')
        else
          for (final category in _storeCategories)
            Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  category.isActive
                      ? Icons.category_rounded
                      : Icons.category_outlined,
                  color: category.isActive
                      ? _storeBrandColor
                      : _storeMutedColor,
                ),
                title: Text(
                  category.nameAr,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${category.nameEn}  •  ترتيب ${category.sortOrder}',
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      tooltip: 'تعديل التصنيف',
                      onPressed: () => _editCategory(category),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: category.isActive ? 'تعطيل' : 'تفعيل',
                      onPressed: () => _toggleCategory(category),
                      icon: Icon(
                        category.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              'العناصر (${_storeItems.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _storeBrandColor),
              onPressed: _createStoreItem,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة عنصر'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_storeItems.isEmpty)
          const Text('لا توجد عناصر في المتجر.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _storeItems.length,
            itemBuilder: (context, index) {
              final item = _storeItems[index];
              final category = _storeCategories
                  .cast<AdminStoreCategory?>()
                  .firstWhere(
                    (value) => value?.id == item.categoryId,
                    orElse: () => null,
                  );
              final price = item.currency == 'FREE'
                  ? 'مجاني'
                  : '${item.price} ${item.currency}';

              return Card(
                elevation: 0,
                child: ListTile(
                  leading: item.imageUrl == null
                      ? const Icon(
                          Icons.shopping_bag_outlined,
                          color: _storeBrandColor,
                        )
                      : SizedBox(
                          width: 48,
                          height: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: WaynNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.shopping_bag_outlined,
                                color: _storeBrandColor,
                              ),
                            ),
                          ),
                        ),
                  title: Text(
                    item.nameAr,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '$price  •  ${category?.nameAr ?? 'بدون تصنيف'}',
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        tooltip: 'تعديل العنصر',
                        onPressed: () => _editStoreItem(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: item.isActive ? 'تعطيل' : 'تفعيل',
                        onPressed: () => _toggleStoreItem(item),
                        icon: Icon(
                          item.isActive
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _storeErrorCard(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message, style: const TextStyle(color: Color(0xFFD95757))),
    );
  }

  Widget _permissionsSection() {
    return _sectionBody(
      loading: _hasLoading,
      hasData: _permissions.isNotEmpty,
      empty: 'لا توجد صلاحيات.',
      error: _permissionsError,
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: _permissions.length,
        itemBuilder: (context, index) {
          final permission = Map<String, dynamic>.from(
            _permissions[index] as Map,
          );

          return Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF18A99A),
              ),
              title: Text(
                permission['name']?.toString() ?? '—',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
              ),
              subtitle: Text(permission['description']?.toString() ?? ''),
              isThreeLine: permission['description'] != null,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];
    for (final section in _sections) {
      tabs.add(Tab(text: section.label));
      views.add(section.body());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: Text(
            'مرحبًا، ${widget.adminName}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_initialLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded),
              ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF18A99A),
            unselectedLabelColor: const Color(0xFF596273),
            indicatorColor: const Color(0xFF18A99A),
            dividerColor: Colors.transparent,
            tabs: tabs,
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: views,
        ),
      ),
    );
  }
}
