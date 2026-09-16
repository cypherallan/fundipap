import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../notifications/notification_service.dart';

class FundiNotificationsBanner extends StatelessWidget {
  const FundiNotificationsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .limit(20)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return const SizedBox.shrink();

        // Filter only fundi-relevant types and sort by createdAt
        var docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          var ta = (a.data() as Map)['createdAt'] is Timestamp
              ? ((a.data() as Map)['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          var tb = (b.data() as Map)['createdAt'] is Timestamp
              ? ((b.data() as Map)['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          return tb.compareTo(ta);
        });

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    size: 16,
                    color: FundipapColors.blackGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'New Updates • ${docs.length}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => NotificationService.markAllAsRead(uid),
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    var data = docs[i].data() as Map<String, dynamic>;
                    String title = data['title'] ?? '';
                    String body = data['body'] ?? '';
                    String type = data['type'] ?? '';

                    IconData icon = Icons.notifications;
                    Color bg = FundipapColors.primaryYellow.withValues(
                      alpha: 0.18,
                    );
                    if (type == 'bid_accepted') {
                      icon = Icons.check_circle;
                      bg = Colors.green.shade50;
                    }
                    if (type == 'escrow_held') {
                      icon = Icons.account_balance_wallet;
                      bg = Colors.blue.shade50;
                    }
                    if (type == 'parts_bought') {
                      icon = Icons.shopping_cart;
                      bg = Colors.orange.shade50;
                    }
                    if (type == 'payment_released') {
                      icon = Icons.payments;
                      bg = Colors.green.shade100;
                    }

                    return InkWell(
                      onTap: () => NotificationService.markAsRead(docs[i].id),
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: FundipapColors.primaryYellow,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: FundipapColors.blackGray,
                              child: Icon(icon, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    body,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
