import 'package:flutter/material.dart';

import 'dashboard/admin_dashboard_page.dart';

/// AdminPanel — retained for compatibility.
///
/// The real admin dashboard is [AdminDashboardPage], which is the screen the
/// app navigates to after a successful admin login. AdminPanel simply renders
/// that dashboard so any code that still references this widget stays
/// functional instead of showing an empty/broken panel.
class AdminPanel extends StatelessWidget {
  final String adminName;

  const AdminPanel({super.key, required this.adminName});

  @override
  Widget build(BuildContext context) {
    return AdminDashboardPage(adminName: adminName);
  }
}