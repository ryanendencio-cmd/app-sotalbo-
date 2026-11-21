import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final notifications = await ApiService.getWorkerNotifications();
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
  final selectedIds = <String>{};
  var isDeleting = false;

  try {
    final notifications = await ApiService.getWorkerNotifications();
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
        builder: (dialogContext, setDialogState) {
          void toggleSelection(String id) {
            setDialogState(() {
              if (selectedIds.contains(id)) {
                selectedIds.remove(id);
              } else {
                selectedIds.add(id);
              }
            });
          }

          final allValidIds = announcements
              .map((a) => a['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          final isSelectionMode = selectedIds.isNotEmpty;
          final isAllSelected = allValidIds.isNotEmpty &&
              selectedIds.length == allValidIds.length;

          void toggleSelectAll() {
            setDialogState(() {
              if (isAllSelected) {
                selectedIds.clear();
              } else {
                selectedIds.addAll(allValidIds);
              }
            });
          }

          Future<void> deleteSelected() async {
            if (isDeleting || selectedIds.isEmpty) return;
            final ids = selectedIds.toList();
            final confirmed = await showDialog<bool>(
              context: dialogContext,
              builder: (confirmationContext) => AlertDialog(
                title: Text(
                  'Delete notifications?',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Delete ${ids.length} selected notification${ids.length == 1 ? '' : 's'} from your account?',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmationContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(confirmationContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA63228),
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;

            setDialogState(() => isDeleting = true);
            try {
              await ApiService.deleteWorkerNotifications(ids);
              announcements.removeWhere(
                (item) => ids.contains(item['id']?.toString()),
              );
              updateWorkerAnnouncementBadge(announcements);
              selectedIds.clear();
              if (pageContext.mounted) {
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${ids.length} notification${ids.length == 1 ? '' : 's'} deleted.',
                    ),
                    backgroundColor: const Color(0xFFA63228),
                  ),
                );
              }
            } catch (error) {
              if (pageContext.mounted) {
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text('Unable to delete notifications: $error'),
                  ),
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => isDeleting = false);
              }
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 540),
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
                          onPressed: isDeleting
                              ? null
                              : () {
                                  Navigator.pop(dialogContext);
                                },
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    if (!isSelectionMode) ...[
                      Text(
                        'Updates on your requests, attendance, and broadcasts',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hold a notification to select & delete.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA63228).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFFA63228).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: isDeleting ? null : toggleSelectAll,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: isAllSelected,
                                      onChanged: isDeleting
                                          ? null
                                          : (_) => toggleSelectAll(),
                                      activeColor: const Color(0xFFA63228),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isAllSelected
                                          ? 'Deselect All'
                                          : 'Select All',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFA63228),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: isDeleting ? null : deleteSelected,
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFA63228),
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline, size: 16),
                              label: Text(
                                'Delete (${selectedIds.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFA63228),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            TextButton(
                              onPressed: isDeleting
                                  ? null
                                  : () => setDialogState(selectedIds.clear),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 16),
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
                                final read = announcement['read'] == true ||
                                    announcement['read']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'true';
                                final isMarking = markingIds.contains(id);
                                final isSelected = selectedIds.contains(id);

                                return GestureDetector(
                                  onLongPress: id.isEmpty || isDeleting
                                      ? null
                                      : () {
                                          HapticFeedback.heavyImpact();
                                          setDialogState(
                                            () => selectedIds.add(id),
                                          );
                                        },
                                  onTap: id.isEmpty || isDeleting
                                      ? null
                                      : () {
                                          if (isSelectionMode) {
                                            toggleSelection(id);
                                            return;
                                          }
                                          Navigator.pop(dialogContext);
                                          if (!pageContext.mounted) return;
                                          _showWorkerAnnouncementDetails(
                                            pageContext,
                                            announcement,
                                          );
                                        },
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFA63228)
                                              .withValues(alpha: 0.08)
                                          : read
                                              ? const Color(0xFFFAF8F5)
                                              : Colors.red.shade50
                                                  .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFA63228)
                                            : read
                                                ? Colors.grey.shade200
                                                : const Color(0xFFA63228)
                                                    .withValues(alpha: 0.3),
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(11),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (isSelectionMode) ...[
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                top: 2,
                                                right: 8,
                                              ),
                                              child: Checkbox(
                                                value: isSelected,
                                                onChanged: isDeleting ||
                                                        id.isEmpty
                                                    ? null
                                                    : (_) =>
                                                        toggleSelection(id),
                                                activeColor: const Color(
                                                  0xFFA63228,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                            ),
                                          ],
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      (announcement[
                                                                  'date'] ??
                                                              '')
                                                          .toString(),
                                                      style:
                                                          GoogleFonts.inter(
                                                        fontSize: 10,
                                                        color: Colors
                                                            .grey.shade600,
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
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    color: read
                                                        ? Colors.black87
                                                        : const Color(
                                                            0xFFA63228,
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  (announcement[
                                                              'message'] ??
                                                          '')
                                                      .toString(),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade700,
                                                  ),
                                                ),
                                                if (!isSelectionMode)
                                                  Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: TextButton.icon(
                                                      onPressed: read ||
                                                              isMarking ||
                                                              id.isEmpty
                                                          ? null
                                                          : () async {
                                                              setDialogState(
                                                                () =>
                                                                    markingIds
                                                                        .add(
                                                                  id,
                                                                ),
                                                              );
                                                              try {
                                                                await ApiService
                                                                    .markWorkerNotificationRead(
                                                                  id,
                                                                );
                                                                announcement[
                                                                        'read'] =
                                                                    true;
                                                                updateWorkerAnnouncementBadge(
                                                                  announcements,
                                                                );
                                                                setDialogState(
                                                                    () {});
                                                              } catch (
                                                                  error) {
                                                                if (pageContext
                                                                    .mounted) {
                                                                  ScaffoldMessenger.of(
                                                                    pageContext,
                                                                  ).showSnackBar(
                                                                    SnackBar(
                                                                      content:
                                                                          Text(
                                                                        'Unable to mark notification as read: $error',
                                                                      ),
                                                                    ),
                                                                  );
                                                                }
                                                              } finally {
                                                                markingIds
                                                                    .remove(
                                                                  id,
                                                                );
                                                                setDialogState(
                                                                    () {});
                                                              }
                                                            },
                                                      icon: Icon(
                                                        read
                                                            ? Icons
                                                                .done_all_rounded
                                                            : Icons
                                                                .mark_email_read_outlined,
                                                        size: 16,
                                                      ),
                                                      label: Text(
                                                        read
                                                            ? 'Read'
                                                            : 'Mark as read',
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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

