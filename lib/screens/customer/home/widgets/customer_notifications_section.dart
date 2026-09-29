import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import 'customer_home_status.dart';
import '../../confirm/confirm_fundi_page.dart';
import '../timeline/customer_fundi_timeline_page.dart';

class CustomerNotificationsSection extends StatelessWidget {
  final List<Map<String, dynamic>> groupedList;
  final Map<String, int> fundiUnreadCounts;
  final int totalTabCounter;
  final Future<void> Function(String fundiKey) onMarkRead;

  const CustomerNotificationsSection({
    super.key,
    required this.groupedList,
    required this.fundiUnreadCounts,
    required this.totalTabCounter,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: FundipapColors.primaryYellow,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    totalTabCounter > 0
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Notifications',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                if (totalTabCounter > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalTabCounter new',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (groupedList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No notifications yet',
                  style: GoogleFonts.inter(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
          ...groupedList.take(5).map((g) {
            String fundiKey = (g['fundiId'] ?? '').toString();
            int badgeCount = fundiUnreadCounts[fundiKey] ?? 0;
            // SAFE CAST - fixes _Map<dynamic,dynamic> error
            final job = Map<String, dynamic>.from(g['jobData'] as Map);
            final bidData = g['bidData'] != null
                ? Map<String, dynamic>.from(g['bidData'] as Map)
                : <String, dynamic>{};
            var status = (job['status'] ?? '').toString();
            bool isCompleted = status == 'completed';
            Color borderCol = isCompleted
                ? Colors.green
                : Colors.orange.shade700;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1.5),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: FundipapColors.blackGray,
                          child: Text(
                            ((g['fundiName'] ?? 'F').toString())[0]
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      (g['category'] ?? 'Job').toString(),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      (g['fundiName'] ?? 'Fundi').toString(),
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () async {
                      await onMarkRead(fundiKey);
                      if (!context.mounted) return;
                      if (g['type'] == 'bid' && g['isPendingBid'] == true) {
                        final confirmed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConfirmFundiPage(
                              jobId: g['jobId'].toString(),
                              jobData: job,
                              bidId: g['bidId'].toString(),
                              bidData: bidData,
                            ),
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerFundiTimelinePage(
                                jobId: g['jobId'].toString(),
                                fundiName: g['fundiName'].toString(),
                                trade: g['category'].toString(),
                                jobData: job,
                              ),
                            ),
                          );
                        }
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerFundiTimelinePage(
                              jobId: g['jobId'].toString(),
                              fundiName: g['fundiName'].toString(),
                              trade: g['category'].toString(),
                              jobData: job,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: HomeStatusWidget(job: job, parentContext: context),
                  ),
                ],
              ),
            );
          }),
          if (groupedList.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Text(
                  '${groupedList.length - 5} more notifications',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black45),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
