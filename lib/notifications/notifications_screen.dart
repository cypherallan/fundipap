import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_service.dart';
import 'notification_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  String _iconForType(String type) {
    switch (type) {
      case 'job_confirmed':
        return '✅';
      case 'escrow_held':
        return '💰';
      case 'site_visit_done':
        return '📍';
      case 'renegotiation_requested':
        return '💬';
      case 'parts_bought':
        return '🛒';
      case 'parts_confirmed':
        return '🔧';
      case 'fundi_working':
        return '👷';
      case 'job_completed':
        return '🎉';
      case 'payment_released':
        return '💵';
      default:
        return '🔔';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => NotificationService.markAllAsRead(userId),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationService.getUserNotificationsStream(userId),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 60,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              var n = AppNotification.fromDoc(docs[i]);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: n.isRead ? Colors.white : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: n.isRead ? Colors.black12 : Colors.blue.shade100,
                  ),
                ),
                child: ListTile(
                  leading: Text(
                    _iconForType(n.type),
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    n.title,
                    style: GoogleFonts.montserrat(
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.body, style: GoogleFonts.inter(fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        n.jobTitle ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black45,
                        ),
                      ),
                      Text(
                        timeago.format(n.createdAt.toDate()),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  trailing: n.isRead
                      ? null
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () async {
                    await NotificationService.markAsRead(n.id);
                    // Navigate to job detail if needed
                    // Navigator.push(...)
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
