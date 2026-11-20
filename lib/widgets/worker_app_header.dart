import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

final ValueNotifier<bool> workerHasUnreadAnnouncements = ValueNotifier(false);

bool isNotificationForWorker(Map<String, dynamic> item, Map<String, dynamic>? user) {
  final type = (item['type'] ?? '').toString().toLowerCase().trim();
  if (type == 'announcement' || type == 'broadcast' || type == 'general') {
    return true;
  }

  if (user == null) {
    return false;
  }

  final userIds = {
    user['id']?.toString().trim(),
    user['worker_id']?.toString().trim(),
    user['workerId']?.toString().trim(),
    user['employee_id']?.toString().trim(),
  }.where((id) => id != null && id.isNotEmpty).toSet();

  final notifWorkerId = (item['worker_id'] ?? item['target_id'] ?? '').toString().trim();
  if (notifWorkerId.isNotEmpty && userIds.contains(notifWorkerId)) {
    return true;
  }

  final nameCandidates = <String>{
    user['name']?.toString() ?? '',
    user['full_name']?.toString() ?? '',
    user['username']?.toString() ?? '',
    [
      user['first_name'] ?? user['firstName'],
      user['middle_name'] ?? user['middleName'],
      user['last_name'] ?? user['lastName'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty).join(' '),
    [
      user['first_name'] ?? user['firstName'],
      user['last_name'] ?? user['lastName'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty).join(' '),
  }.where((s) => s.trim().length >= 3).map((s) => s.trim().toLowerCase()).toSet();

  final title = (item['title'] ?? '').toString().toLowerCase();
  final message = (item['message'] ?? '').toString().toLowerCase();

  for (final name in nameCandidates) {
    if (title.contains(name) || message.contains(name)) {
      return true;
    }
  }

  return false;
}

void updateWorkerAnnouncementBadge(Iterable<Map<String, dynamic>> items) {
  final user = ApiService.currentUser;
  workerHasUnreadAnnouncements.value = items.any((item) {
    if (!isNotificationForWorker(item, user)) return false;
    final isRead =
        item['read'] == true ||
        item['read']?.toString().toLowerCase() == 'true';
    return !isRead;
  });
}

Future<void> refreshWorkerAnnouncementBadge() async {
  try {
    final notifications = await ApiService.getNotifications();
    final items = notifications
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    updateWorkerAnnouncementBadge(items);
  } catch (error) {
    debugPrint('Failed to refresh announcement badge: $error');
  }
}

class WorkerAppHeader extends StatefulWidget implements PreferredSizeWidget {
  const WorkerAppHeader({
    super.key,
    this.bottom,
    this.actions = const [],
    this.leading,
    this.automaticallyImplyLeading = false,
    this.onNotificationsPressed,
  });

  final PreferredSizeWidget? bottom;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Future<void> Function()? onNotificationsPressed;

  static const _brandColor = Color(0xFFA63228);

  @override
  Size get preferredSize =>
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  State<WorkerAppHeader> createState() => _WorkerAppHeaderState();
}

class _WorkerAppHeaderState extends State<WorkerAppHeader> {
  Timer? _notifPollTimer;

  @override
  void initState() {
    super.initState();
    refreshWorkerAnnouncementBadge();
    _notifPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        refreshWorkerAnnouncementBadge();
      }
    });
  }

  @override
  void dispose() {
    _notifPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _openAnnouncements() async {
    if (widget.onNotificationsPressed != null) {
      await widget.onNotificationsPressed!();
    } else {
      await showWorkerAnnouncements(context);
    }
    await refreshWorkerAnnouncementBadge();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      leading: widget.leading,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 56,
      title: Image.asset('assets/logo.png', height: 28),
      centerTitle: true,
      actions: [
        ...widget.actions,
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black87,
                size: 22,
              ),
              tooltip: 'Notifications & Alerts',
              onPressed: _openAnnouncements,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: workerHasUnreadAnnouncements,
              builder: (context, hasUnread, child) => hasUnread
                  ? Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: WorkerAppHeader._brandColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      bottom: widget.bottom,
    );
  }
}

Widget _buildNotificationTypeBadge(Map<String, dynamic> notif) {
  final type = (notif['type'] ?? '').toString().toLowerCase();
  final title = (notif['title'] ?? '').toString().toLowerCase();
  final message = (notif['message'] ?? '').toString().toLowerCase();

  Color bgColor;
  Color textColor;
  String label;

  if (title.contains('rejected') || message.contains('rejected')) {
    bgColor = const Color(0xFFFFEBEE);
    textColor = const Color(0xFFC62828);
    label = 'Rejected';
  } else if (title.contains('approved') || message.contains('approved')) {
    bgColor = const Color(0xFFE8F5E9);
    textColor = const Color(0xFF2E7D32);
    label = 'Approved';
  } else if (type == 'attendance' || title.contains('early-out') || title.contains('correction')) {
    bgColor = const Color(0xFFFFF3E0);
    textColor = const Color(0xFFE65100);
    label = 'Attendance';
  } else if (type == 'cash advance' || title.contains('cash advance') || title.contains('vale')) {
    bgColor = const Color(0xFFE3F2FD);
    textColor = const Color(0xFF1565C0);
    label = 'Cash Advance';
  } else {
    bgColor = const Color(0xFFF5F5F5);
    textColor = Colors.grey.shade700;
    label = 'Broadcast';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    ),
  );
}

Future<void> showWorkerAnnouncements(BuildContext context) async {
  final pageContext = context;
  final markingIds = <String>{};
  try {
    final notifications = await ApiService.getNotifications();
    if (!pageContext.mounted) return;
    final user = ApiService.currentUser;
    final announcements = notifications
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => isNotificationForWorker(item, user))
        .toList();
    updateWorkerAnnouncementBadge(announcements);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: WorkerAppHeader._brandColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifications & Alerts',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  Text(
                    'Updates on your requests, attendance, and broadcasts',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: announcements.isEmpty
                        ? Center(
                            child: Text(
                              'No notifications at this time.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: announcements.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final announcement = announcements[index];
                              final rawId = announcement['id'];
                              final id = rawId?.toString() ?? '';
                              final read =
                                  announcement['read'] == true ||
                                  announcement['read']
                                          ?.toString()
                                          .toLowerCase() ==
                                      'true';
                              final isMarking = markingIds.contains(id);
                              return Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: read
                                      ? const Color(0xFFFAF8F5)
                                      : Colors.red.shade50.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: read
                                        ? Colors.grey.shade200
                                        : const Color(0xFFA63228).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        if (!pageContext.mounted) return;
                                        _showWorkerAnnouncementDetails(
                                          pageContext,
                                          announcement,
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                (announcement['date'] ?? '')
                                                    .toString(),
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              _buildNotificationTypeBadge(
                                                announcement,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (announcement['title'] ??
                                                    'Notification')
                                                .toString(),
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: read
                                                  ? Colors.black87
                                                  : const Color(0xFFA63228),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            (announcement['message'] ?? '')
                                                .toString(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed:
                                            read || isMarking || id.isEmpty
                                            ? null
                                            : () async {
                                                setDialogState(
                                                  () => markingIds.add(id),
                                                );
                                                try {
                                                  await ApiService.markNotificationRead(
                                                    id,
                                                  );
                                                  announcement['read'] = true;
                                                  updateWorkerAnnouncementBadge(
                                                    announcements,
                                                  );
                                                  setDialogState(() {});
                                                } catch (error) {
                                                  if (pageContext.mounted) {
                                                    ScaffoldMessenger.of(
                                                      pageContext,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Unable to mark notification as read: $error',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } finally {
                                                  markingIds.remove(id);
                                                  setDialogState(() {});
                                                }
                                              },
                                        icon: Icon(
                                          read
                                              ? Icons.done_all_rounded
                                              : Icons.mark_email_read_outlined,
                                          size: 16,
                                        ),
                                        label: Text(
                                          read ? 'Read' : 'Mark as read',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  } catch (error) {
    if (!pageContext.mounted) return;
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(content: Text('Unable to load announcements: $error')),
    );
  }
}

Future<void> _showWorkerAnnouncementDetails(
  BuildContext context,
  Map<String, dynamic> announcement,
) {
  final date = (announcement['date'] ?? '').toString().trim();
  final time = (announcement['time'] ?? '').toString().trim();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        (announcement['title'] ?? 'Announcement').toString(),
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date.isNotEmpty || time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  [
                    if (date.isNotEmpty) date,
                    if (time.isNotEmpty) time,
                  ].join(' • '),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            Text(
              (announcement['message'] ?? 'No additional details.').toString(),
              style: GoogleFonts.inter(fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
