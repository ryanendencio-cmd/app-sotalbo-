import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

class AdminMobileAppBar extends StatefulWidget implements PreferredSizeWidget {
  const AdminMobileAppBar({
    super.key,
    this.leading,
    this.actions = const [],
    this.onNotificationsPressed,
    this.unreadCount,
    this.onLogoutPressed,
    this.bottom,
  });

  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onNotificationsPressed;
  final int? unreadCount;
  final VoidCallback? onLogoutPressed;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  State<AdminMobileAppBar> createState() => _AdminMobileAppBarState();
}

class _AdminMobileAppBarState extends State<AdminMobileAppBar> {
  static const _primary = Color(0xFFA63228);

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.onNotificationsPressed == null) _loadNotifications();
  }

  int get _unreadCount =>
      widget.unreadCount ??
      _notifications.where((notification) {
        final read = notification['read'];
        return read != true && read?.toString().toLowerCase() != 'true';
      }).length;

  Future<void> _loadNotifications() async {
    if (widget.onNotificationsPressed != null) {
      widget.onNotificationsPressed!();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load notifications: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _showNotifications() async {
    if (widget.onNotificationsPressed != null) {
      widget.onNotificationsPressed!();
      return;
    }

    await _loadNotifications();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _unreadCount == 0
                            ? null
                            : () async {
                                try {
                                  await ApiService.markAllNotificationsRead();
                                  if (!mounted) return;
                                  setState(() {
                                    for (final notification in _notifications) {
                                      notification['read'] = true;
                                    }
                                  });
                                  setSheetState(() {});
                                } catch (error) {
                                  _showError(
                                    'Unable to mark notifications as read: $error',
                                  );
                                }
                              },
                        child: const Text('Mark all read'),
                      ),
                      IconButton(
                        tooltip: 'Refresh notifications',
                        onPressed: () async {
                          await _loadNotifications();
                          if (sheetContext.mounted) setSheetState(() {});
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : _notifications.isEmpty
                      ? Center(
                          child: Text(
                            'No notifications.',
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final read =
                                notification['read'] == true ||
                                notification['read']
                                        ?.toString()
                                        .toLowerCase() ==
                                    'true';
                            return ListTile(
                              leading: Icon(
                                read
                                    ? Icons.notifications_none_rounded
                                    : Icons.notifications_active_rounded,
                                color: read ? Colors.grey : _primary,
                              ),
                              title: Text(
                                (notification['title'] ?? 'Notification')
                                    .toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: read
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                (notification['message'] ?? '').toString(),
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                              onTap: read
                                  ? null
                                  : () async {
                                      final id = notification['id'];
                                      if (id == null) return;
                                      try {
                                        await ApiService.markNotificationRead(
                                          id,
                                        );
                                        if (!mounted) return;
                                        setState(
                                          () => notification['read'] = true,
                                        );
                                        setSheetState(() {});
                                      } catch (error) {
                                        _showError(
                                          'Unable to mark notification as read: $error',
                                        );
                                      }
                                    },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: _primary));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (error) {
      _showError('Unable to log out: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: widget.leading,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.black87),
      title: Image.asset('assets/logo.png', height: 30),
      bottom: widget.bottom,
      actions: [
        ...widget.actions,
        IconButton(
          tooltip: 'Notifications',
          onPressed: _showNotifications,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (_unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadCount > 99 ? '99+' : '$_unreadCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) {
            if (value == 'logout') {
              if (widget.onLogoutPressed != null) {
                widget.onLogoutPressed!();
              } else {
                _logout();
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: _primary),
                  SizedBox(width: 10),
                  Text('Log Out', style: TextStyle(color: _primary)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AdminMobileBottomNavigationBar extends StatefulWidget {
  const AdminMobileBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.pendingCashAdvances,
    this.pendingWorkers,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? pendingCashAdvances;
  final int? pendingWorkers;

  @override
  State<AdminMobileBottomNavigationBar> createState() =>
      _AdminMobileBottomNavigationBarState();
}

class _AdminMobileBottomNavigationBarState
    extends State<AdminMobileBottomNavigationBar> {
  int _pendingCashAdvances = 0;
  int _pendingWorkers = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingCounts();
  }

  Future<void> _loadPendingCounts() async {
    if (widget.pendingCashAdvances != null && widget.pendingWorkers != null) {
      return;
    }

    try {
      final results = await Future.wait([
        if (widget.pendingCashAdvances == null)
          ApiService.getPendingCashAdvances(),
        if (widget.pendingWorkers == null) ApiService.getPendingRegistrations(),
      ]);
      if (!mounted) return;
      var index = 0;
      setState(() {
        if (widget.pendingCashAdvances == null) {
          _pendingCashAdvances = results[index++].length;
        }
        if (widget.pendingWorkers == null) {
          _pendingWorkers = results[index].length;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load pending navigation counts: $error'),
          backgroundColor: const Color(0xFFA63228),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCashAdvances =
        widget.pendingCashAdvances ?? _pendingCashAdvances;
    final pendingWorkers = widget.pendingWorkers ?? _pendingWorkers;
    return BottomNavigationBar(
      currentIndex: widget.currentIndex,
      onTap: widget.onTap,
      selectedItemColor: const Color(0xFFA63228),
      unselectedItemColor: Colors.grey.shade500,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined),
          activeIcon: Icon(Icons.grid_view_rounded),
          label: 'Overview',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.handyman_outlined),
          activeIcon: Icon(Icons.handyman_rounded),
          label: 'Tools',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: pendingCashAdvances > 0,
            label: Text('$pendingCashAdvances'),
            child: const Icon(Icons.payments_outlined),
          ),
          activeIcon: Badge(
            isLabelVisible: pendingCashAdvances > 0,
            label: Text('$pendingCashAdvances'),
            child: const Icon(Icons.payments_rounded),
          ),
          label: 'Cash Adv',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: pendingWorkers > 0,
            label: Text('$pendingWorkers'),
            child: const Icon(Icons.groups_outlined),
          ),
          activeIcon: Badge(
            isLabelVisible: pendingWorkers > 0,
            label: Text('$pendingWorkers'),
            child: const Icon(Icons.groups_rounded),
          ),
          label: 'Workers',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.fact_check_outlined),
          activeIcon: Icon(Icons.fact_check_rounded),
          label: 'Attendance',
        ),
      ],
    );
  }
}

void navigateAdminMobileSection(BuildContext context, int index) {
  if (index == 4) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/attendance_management',
      (_) => false,
    );
    return;
  }
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/admin_dashboard',
    (_) => false,
    arguments: index,
  );
}
