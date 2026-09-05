import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/wayn_api.dart';

const _brandColor = Color(0xFF18A99A);

/// Permission name -> human-friendly Arabic label used by the management
/// UI. Unknown permissions fall back to the raw name.
String permissionLabel(String name) {
  const labels = <String, String>{
    'users.read': 'عرض المستخدمين',
    'users.write': 'إضافة/تعديل المستخدمين',
    'users.update': 'تعديل المستخدمين',
    'users.delete': 'حذف المستخدمين',
    'users.disable': 'تعطيل المستخدمين',
    'places.read': 'قراءة الأماكن',
    'places.write': 'إضافة الأماكن',
    'places.update': 'تعديل الأماكن',
    'places.delete': 'حذف الأماكن',
    'places.approve': 'اعتماد الأماكن',
    'categories.read': 'عرض التصنيفات',
    'categories.write': 'إضافة تصنيف',
    'categories.update': 'تعديل تصنيف',
    'categories.delete': 'حذف تصنيف',
    'reports.read': 'عرض البلاغات',
    'reports.write': 'إدارة البلاغات',
    'reports.resolve': 'حل البلاغات',
    'community.read': 'عرض المنشورات',
    'community.moderate': 'إدارة المنشورات',
    'contributions.read': 'عرض المساهمات',
    'contributions.approve': 'اعتماد المساهمات',
    'contributions.reject': 'رفض المساهمات',
    'wallet.read': 'عرض المحافظ',
    'wallet.recharge': 'شحن المحافظ',
    'wallet.adjust': 'تعديل الرصيد',
    'wallet.transactions': 'عرض المعاملات',
    'store.read': 'عرض العروض',
    'store.write': 'إضافة عرض',
    'store.update': 'تعديل عرض',
    'store.delete': 'حذف عرض',
    'admin.manage_admins': 'إدارة المشرفين',
  };

  return labels[name] ?? name;
}

/// Arabic group label for a permission (uses the dotted prefix).
String permissionGroup(String name) {
  if (name.startsWith('places.')) return 'إدارة الأماكن';
  if (name.startsWith('users.')) return 'إدارة المستخدمين';
  if (name.startsWith('categories.')) return 'إدارة التصنيفات';
  if (name.startsWith('wallet.')) return 'إدارة المحافظ';
  if (name.startsWith('store.')) return 'إدارة العروض';
  if (name.startsWith('community.') || name.startsWith('reports.')) {
    return 'إدارة المجتمع';
  }
  if (name.startsWith('contributions.')) return 'المساهمات';
  if (name.startsWith('admin.')) return 'الإدارة';
  return 'أخرى';
}

/// "إدارة المشرفين" screen for Super Admins only.
class AdminManagePage extends StatefulWidget {
  final VoidCallback? onChanged;

  const AdminManagePage({super.key, this.onChanged});

  @override
  State<AdminManagePage> createState() => _AdminManagePageState();
}

class _AdminManagePageState extends State<AdminManagePage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _admins = [];
  List<Map<String, dynamic>> _allPermissions = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final admins = List<dynamic>.from(
        await waynAdminApi.get('/api/v1/admin/users'),
      );
      final perms = List<dynamic>.from(
        await waynAdminApi.get('/api/v1/admin/permissions'),
      );

      if (!mounted) return;
      setState(() {
        _admins = admins;
        _allPermissions = [
          for (final p in perms) Map<String, dynamic>.from(p as Map),
        ];
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is ApiClientException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<List<int>> _loadAdminPermissionIds(dynamic adminId) async {
    final data = await waynAdminApi.get(
      '/api/v1/admin/users/$adminId/permissions',
    );
    final ids = <int>[];
    if (data is List) {
      for (final item in data) {
        final id = (item as Map)['id'];
        if (id is int) ids.add(id);
      }
    }
    return ids;
  }

  void _openCreate() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _AdminEditorDialog(allPermissions: _allPermissions),
    );
    widget.onChanged?.call();
    _loadAll();
  }

  void _openPermissions(Map<String, dynamic> admin) async {
    final current = await _loadAdminPermissionIds(admin['id']);
    if (!mounted) return;
    await showDialog<bool>(
      context: context,
      builder: (_) => _AdminPermissionsDialog(
        admin: admin,
        allPermissions: _allPermissions,
        initialSelected: current,
      ),
    );
    if (!mounted) return;
    widget.onChanged?.call();
    _loadAll();
  }

  Future<void> _toggleActive(Map<String, dynamic> admin) async {
    final adminId = admin['id'];
    final activate = !(admin['is_active'] == true);

    try {
      // Use the dedicated activate/deactivate routes so the state
      // change is explicit on the backend (PUT is kept for full
      // updates by the API contract).
      await waynAdminApi.patch(
        '/api/v1/admin/users/$adminId/${activate ? 'activate' : 'deactivate'}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              activate ? 'تم تفعيل المشرف' : 'تم تعطيل المشرف',
              textDirection: TextDirection.rtl,
            ),
          ),
        );

      _loadAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  Future<void> _deleteAdmin(Map<String, dynamic> admin) async {
    final adminId = admin['id'];
    final name = admin['full_name']?.toString() ?? '';

    // Confirmation first: deleting an admin removes their
    // administrative powers but keeps their normal WAYN account.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف المشرف'),
          content: Text(
            name.isEmpty
                ? 'سيتم حذف صلاحيات هذا المشرف نهائيًا. '
                    'هل تريد المتابعة؟\n\nملاحظة: حساب WAYN العادي '
                    'المرتبط بنفس البريد لن يُحذف.'
                : 'سيتم حذف صلاحيات المشرف "$name" نهائيًا. '
                    'هل تريد المتابعة؟\n\nملاحظة: حساب WAYN العادي '
                    'المرتبط بنفس البريد لن يُحذف.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD95757),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await waynAdminApi.delete('/api/v1/admin/users/$adminId');

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text(
              'تم حذف المشرف',
              textDirection: TextDirection.rtl,
            ),
          ),
        );

      widget.onChanged?.call();
      _loadAll();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: const Text(
            'إدارة المشرفين',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: _brandColor),
              onPressed: _allPermissions.isEmpty ? null : _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مشرف'),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Color(0xFFD95757))),
      );
    }
    if (_admins.isEmpty) {
      return const Center(child: Text('لا يوجد مشرفون بعد.'));
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _admins.length,
        separatorBuilder: (a, b) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final admin = Map<String, dynamic>.from(_admins[index] as Map);
          final roles = admin['roles'];
          final roleText = roles is List && roles.isNotEmpty
              ? roles.map((r) => r.toString()).join(' • ')
              : '';
          final rawPerms = admin['permissions'];
          final permissionCount = rawPerms is List
              ? List<dynamic>.from(rawPerms).length
              : 0;
          return _AdminCard(
            admin: admin,
            roleText: roleText,
            permissionCount: permissionCount,
            isActive: admin['is_active'] == true,
            onEditPermissions: () => _openPermissions(admin),
            onToggleActive: () => _toggleActive(admin),
            onDelete: () => _deleteAdmin(admin),
            onRefreshed: _loadAll,
          );
        },
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final Map<String, dynamic> admin;
  final String roleText;
  final int permissionCount;
  final bool isActive;
  final VoidCallback onEditPermissions;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final Future<void> Function() onRefreshed;

  const _AdminCard({
    required this.admin,
    required this.roleText,
    required this.permissionCount,
    required this.isActive,
    required this.onEditPermissions,
    required this.onToggleActive,
    required this.onDelete,
    required this.onRefreshed,
  });

  bool get _isSuperAdmin {
    final roles = admin['roles'];
    if (roles is List) {
      return roles.contains('super_admin');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = admin['full_name']?.toString() ?? '—';
    final email = admin['email']?.toString() ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? const Color(0xFFD0EAE8) : const Color(0xFFFED7D7),
        ),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE8F8F6),
          child: Icon(Icons.person, color: Color(0xFF18A99A)),
        ),
        title: Text(
          fullName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$email\n$roleText'),
        isThreeLine: roleText.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isActive ? 'نشط' : 'معطل',
                  style: const TextStyle(fontSize: 12),
                ),
                value: isActive,
                // Disable toggle for Super Admin (backend enforces 403)
                onChanged: _isSuperAdmin ? null : (_) => onToggleActive(),
              ),
            ),
            // Hide Delete for Super Admin
            // Backend also enforces this with 403
            if (!_isSuperAdmin)
              IconButton(
                tooltip: 'حذف المشرف',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFD95757),
                ),
                onPressed: onDelete,
              ),
          ],
        ),
        onTap: onEditPermissions,
      ),
    );
  }
}

// ============================================================
// Create admin dialog
// ============================================================
class _AdminEditorDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allPermissions;

  const _AdminEditorDialog({required this.allPermissions});

  @override
  State<_AdminEditorDialog> createState() => _AdminEditorDialogState();
}

class _AdminEditorDialogState extends State<_AdminEditorDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isActive = true;
  bool _saving = false;
  String? _error;
  final Set<int> _selected = <int>{};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;

    if (name.isEmpty) {
      setState(() => _error = 'الاسم مطلوب.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'البريد الإلكتروني مطلوب.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'كلمة المرور يجب 8 أحرف على الأقل.');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    try {
      await waynAdminApi.post(
        '/api/v1/admin/users',
        body: {
          'email': email,
          'password': password,
          'full_name': name,
          'is_active': _isActive,
          'role_ids': const [],
          'permission_ids': _selected.toList()..sort(),
        },
      );

      // Admin created with permissions atomically
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('إضافة مشرف'),
        // The permission list is long (30+ switches). The scroll view
        // must live INSIDE the height-constrained area — otherwise the
        // ConstrainedBox bounds the Column itself and the dialog
        // overflows ("BOTTOM OVERFLOWED BY ... PIXELS") instead of
        // scrolling.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'الاسم', keyboard: TextInputType.name),
                const SizedBox(height: 10),
                _field(
                  _email,
                  'البريد الإلكتروني',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                _field(
                  _password,
                  'كلمة المرور',
                  obscure: true,
                  keyboard: TextInputType.visiblePassword,
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الحساب فعال'),
                  value: _isActive,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'الصلاحيات',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF596273),
                  ),
                ),
                const SizedBox(height: 6),
                _permissionSwitches(
                  widget.allPermissions,
                  _selected,
                  _saving,
                  onToggle: (id, v) => setState(() {
                    if (v) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  }),
                ),
                if (_error != null) _errorText(_error!),
              ],
            ),
          ),
        ),
        actions: _actions(context, _submit, _saving),
      ),
    );
  }
}

// ============================================================
// Edit permissions dialog
// ============================================================
class _AdminPermissionsDialog extends StatefulWidget {
  final Map<String, dynamic> admin;
  final List<Map<String, dynamic>> allPermissions;
  final List<int> initialSelected;

  const _AdminPermissionsDialog({
    required this.admin,
    required this.allPermissions,
    required this.initialSelected,
  });

  @override
  State<_AdminPermissionsDialog> createState() =>
      _AdminPermissionsDialogState();
}

class _AdminPermissionsDialogState extends State<_AdminPermissionsDialog> {
  late final Set<int> _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = <int>{...widget.initialSelected};
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.admin['full_name']?.toString() ?? '';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('تعديل صلاحيات: $name'),
        // Same scroll fix as the create dialog: constrain first, then
        // scroll inside it so long permission lists scroll instead of
        // overflowing the dialog.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _permissionSwitches(
                  widget.allPermissions,
                  _selected,
                  _saving,
                  onToggle: (id, v) => setState(() {
                    if (v) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  }),
                ),
                if (_error != null) _errorText(_error!),
              ],
            ),
          ),
        ),
        actions: _actions(context, _submit, _saving),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await waynAdminApi.put(
        '/api/v1/admin/users/${widget.admin['id']}/permissions',
        body: {'permission_ids': _selected.toList()..sort()},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _friendlyError(error);
      });
    }
  }
}

// ============================================================
// Shared UI helpers
// ============================================================

String _friendlyError(Object error) {
  if (error is ApiClientException) return error.message;
  return error.toString().replaceFirst('Exception: ', '');
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool obscure = false,
  TextInputType? keyboard,
}) {
  return TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    textDirection: TextDirection.ltr,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF788591)),
    ),
  );
}

Widget _errorText(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(text, style: const TextStyle(color: Color(0xFFD95757))),
    ),
  );
}

List<Widget> _actions(
  BuildContext context,
  Future<void> Function() onConfirm,
  bool saving,
) {
  return [
    TextButton(
      onPressed: saving ? null : () => Navigator.of(context).pop(false),
      child: const Text('إلغاء'),
    ),
    FilledButton(
      style: FilledButton.styleFrom(backgroundColor: _brandColor),
      onPressed: saving ? null : onConfirm,
      child: saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('حفظ'),
    ),
  ];
}

/// Grouped ON/OFF permission switches.
Widget _permissionSwitches(
  List<Map<String, dynamic>> permissions,
  Set<int> selected,
  bool enabled, {
  void Function(int id, bool value)? onToggle,
}) {
  final groups = <String, List<Map<String, dynamic>>>{};
  final order = <String>[];

  for (final p in permissions) {
    final name = p['name']?.toString() ?? '';
    final group = permissionGroup(name);
    groups.putIfAbsent(group, () {
      order.add(group);
      return <Map<String, dynamic>>[];
    });
    groups[group]!.add(p);
  }

  final widgets = <Widget>[];

  for (final group in order) {
    final perms = groups[group]!;
    perms.sort(
      (a, b) => permissionLabel(
        a['name']?.toString() ?? '',
      ).compareTo(permissionLabel(b['name']?.toString() ?? '')),
    );

    widgets.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          group,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF596273),
          ),
        ),
      ),
    );

    for (final p in perms) {
      final id = _toId(p['id']);
      final name = p['name']?.toString() ?? '';
      final checked = selected.contains(id);

      widgets.add(
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          title: Text(permissionLabel(name)),
          value: checked,
          onChanged: enabled ? (v) => onToggle?.call(id, v) : null,
        ),
      );
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: widgets,
  );
}

int _toId(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

// Toggle callback is now passed via onToggle parameter
