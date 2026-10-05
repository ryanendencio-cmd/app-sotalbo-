import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Shared navigation drawer used throughout the mobile app.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const _primaryColor = Color(0xFFA63228);

  void _goTo(BuildContext context, String route) {
    Navigator.of(context).pop();
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final role = ApiService.currentUserRole ?? 'worker';
    final isAdmin = role == 'admin';
    final isStaff = role == 'staff';
    final isTool = role == 'tool';
    final isWorker = role == 'worker';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 18),
              color: _primaryColor,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.construction_rounded, color: Colors.white, size: 28),
                  SizedBox(height: 10),
                  Text(
                    'S-CON BuildTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mobile navigation',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionLabel('WORKSPACES'),
                  if (isWorker) _item(
                    context,
                    currentRoute,
                    route: '/worker_dashboard',
                    icon: Icons.dashboard_outlined,
                    label: 'Worker Dashboard',
                  ),
                  if (isStaff) _item(
                    context,
                    currentRoute,
                    route: '/timekeeper_dashboard',
                    icon: Icons.fact_check_outlined,
                    label: 'Timekeeper Dashboard',
                  ),
                  if (isTool) _item(
                    context,
                    currentRoute,
                    route: '/tools_monitoring',
                    icon: Icons.handyman_outlined,
                    label: 'Tools Monitoring',
                  ),
                  if (isAdmin) _item(
                    context,
                    currentRoute,
                    route: '/admin_dashboard',
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Admin Dashboard',
                  ),
                  if (isAdmin) _item(
                    context,
                    currentRoute,
                    route: '/admin_profile',
                    icon: Icons.manage_accounts_outlined,
                    label: 'Admin Profile',
                  ),
                  if (isAdmin) ...[
                    const Divider(height: 24),
                    _sectionLabel('APPROVALS & MONITORING'),
                    _item(
                      context,
                      currentRoute,
                      route: '/cash_advance',
                      icon: Icons.payments_outlined,
                      label: 'Cash Advance Requests',
                    ),
                    _item(
                      context,
                      currentRoute,
                      route: '/workers',
                      icon: Icons.people_outline,
                      label: 'Account Approvals',
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: _primaryColor),
              title: const Text(
                'Log out',
                style: TextStyle(fontWeight: FontWeight.w700, color: _primaryColor),
              ),
              onTap: () {
                ApiService.currentUserRole = null;
                ApiService.clearToken();
                _goTo(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF857A72),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String? currentRoute, {
    required String route,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentRoute == route ||
        (route == '/worker_dashboard' && currentRoute == '/dashboard') ||
        (route == '/timekeeper_dashboard' && currentRoute == '/timekeeper');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected ? _primaryColor.withValues(alpha: 0.10) : null,
        leading: Icon(icon, color: isSelected ? _primaryColor : const Color(0xFF514A46)),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? _primaryColor : const Color(0xFF2F2A27),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        onTap: () => _goTo(context, route),
      ),
    );
  }
}

/// Use this in an AppBar that intentionally disables Flutter's implied leading
/// button, so the sidebar remains available.
class AppSidebarMenuButton extends StatelessWidget {
  const AppSidebarMenuButton({super.key, this.color = const Color(0xFF2F2A27)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => IconButton(
        tooltip: 'Open navigation menu',
        icon: Icon(Icons.menu_rounded, color: color),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }
}

/// Menu control for full-screen pages that do not use an AppBar.
class AppSidebarOverlayButton extends StatelessWidget {
  const AppSidebarOverlayButton({super.key, this.darkBackground = false});

  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final foreground = darkBackground ? Colors.white : const Color(0xFF2F2A27);
    final background = darkBackground ? Colors.black.withValues(alpha: 0.30) : Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: background,
            elevation: darkBackground ? 0 : 2,
            shape: const CircleBorder(),
            child: AppSidebarMenuButton(color: foreground),
          ),
        ),
      ),
    );
  }
}
