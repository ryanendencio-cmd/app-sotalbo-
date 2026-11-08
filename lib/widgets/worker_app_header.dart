import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class WorkerAppHeader extends StatelessWidget implements PreferredSizeWidget {
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
  final VoidCallback? onNotificationsPressed;

  static const _brandColor = Color(0xFFA63228);

  @override
  Size get preferredSize =>
      Size.fromHeight(56 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: 56,
      title: Image.asset('assets/logo.png', height: 28),
      centerTitle: true,
      actions: [
        ...actions,
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black87,
                size: 22,
              ),
              tooltip: 'Announcements',
              onPressed:
                  onNotificationsPressed ??
                  () => showWorkerAnnouncements(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 42),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _brandColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}

Future<void> showWorkerAnnouncements(BuildContext context) async {
  final pageContext = context;
  final markingIds = <String>{};
  try {
    final notifications = await ApiService.getNotifications();
    if (!pageContext.mounted) return;
    final announcements = notifications
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where(
          (item) =>
              (item['type'] ?? '').toString().toLowerCase() == 'announcement',
        )
        .toList();

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
                          'Broadcast Alerts',
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
                    'Messages from the Admin',
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
                              'No announcements at this time.',
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
                                  color: const Color(0xFFFAF8F5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
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
                                          Text(
                                            (announcement['date'] ?? '')
                                                .toString(),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (announcement['title'] ??
                                                    'Announcement')
                                                .toString(),
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
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
                                                  setDialogState(() {});
                                                } catch (error) {
                                                  if (pageContext.mounted) {
                                                    ScaffoldMessenger.of(
                                                      pageContext,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Unable to mark announcement as read: $error',
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
