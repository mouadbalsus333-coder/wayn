import 'package:flutter/material.dart';

import '../../core/network/wayn_api.dart';
import '../../models/store.dart';

class AdminPanel extends StatefulWidget {
  final String adminName;

  const AdminPanel({super.key, required this.adminName});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _tab = 0;
  List<dynamic> _users = [];
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        waynAdminApi.get('/api/v1/admin/users'),
        waynAdminApi.get(
          '/api/v1/store/items',
          queryParams: {'active_only': false},
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _users = List<dynamic>.from(results[0] as List);
        _items = List<dynamic>.from(results[1] as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await waynAdminApi.clearAuthToken();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      _usersView(),
      _placesView(),
      _storeView(),
      _permissionsView(),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: Text(
            'مرحباً، ${widget.adminName}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _overview(),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: views[_tab],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) {
            setState(() => _tab = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'المستخدمون',
            ),
            NavigationDestination(
              icon: Icon(Icons.place_outlined),
              label: 'الأماكن',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              label: 'المتجر',
            ),
            NavigationDestination(
              icon: Icon(Icons.security_outlined),
              label: 'الصلاحيات',
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Row(
        children: [
          _stat('المستخدمون', _users.length, Icons.people_rounded),
          const SizedBox(width: 10),
          _stat('عناصر المتجر', _items.length, Icons.storefront_rounded),
          const SizedBox(width: 10),
          _stat('الصلاحيات', 0, Icons.security_rounded),
        ],
      ),
    );
  }

  Widget _stat(String title, int count, IconData icon) {
    return Expanded(
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
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF7A8494),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _usersView() {
    return ListView.builder(
      key: const ValueKey('users'),
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
              child: Icon(
                Icons.person,
                color: Color(0xFF18A99A),
              ),
            ),
            title: Text(
              user['full_name']?.toString() ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${user['email'] ?? ''}\n$roleText',
            ),
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
    );
  }

  Widget _placesView() {
    return ListView(
      key: const ValueKey('places'),
      padding: const EdgeInsets.all(18),
      children: [
        _adminCard(
          Icons.add_location_alt_rounded,
          'إدارة الأماكن',
          'واجهة إدارة الأماكن والصلاحيات الخاصة بها.',
          'سنطابق حقول هذه الشاشة مع schemas الخاصة بـ admin_places في المرحلة التالية.',
        ),
      ],
    );
  }

  Widget _storeView() {
    return ListView.builder(
      key: const ValueKey('store'),
      padding: const EdgeInsets.all(18),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = StoreItem.fromMap(
          Map<String, dynamic>.from(_items[index] as Map),
        );

        return Card(
          elevation: 0,
          child: ListTile(
            leading: const Icon(
              Icons.shopping_bag_outlined,
              color: Color(0xFF18A99A),
            ),
            title: Text(
              item.nameAr,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${item.price} ${item.currency}'),
            trailing: PopupMenuButton<String>(
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('تعديل'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _permissionsView() {
    return ListView(
      key: const ValueKey('permissions'),
      padding: const EdgeInsets.all(18),
      children: [
        _adminCard(
          Icons.shield_outlined,
          'الأدوار والصلاحيات',
          'واجهة RBAC للإدارة: المستخدمون الإداريون والأدوار والصلاحيات.',
          'لا يتم تجاوز حماية الـBackend من الواجهة.',
        ),
      ],
    );
  }

  Widget _adminCard(
    IconData icon,
    String title,
    String description,
    String note,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF18A99A), size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF596273)),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8B94A3),
            ),
          ),
        ],
      ),
    );
  }
}
