import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import 'customer_home_status.dart';
import '../timeline/customer_fundi_timeline_page.dart';
import 'pending/pending_bid_list.dart';
import '../models/customer_home_models.dart';

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

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  bool _toBool(dynamic v, [bool fb = false]) {
    if (v == null) return fb;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return fb;
  }

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
            final job = Map<String, dynamic>.from(g['jobData'] as Map);
            final type = (g['type'] ?? '').toString();
            final isBid = type == 'bid';

            final bidStatus = (g['bidStatus'] ?? job['bidStatus'] ?? '')
                .toString();
            final isCounterAccepted =
                bidStatus.contains('counter_accepted_by_fundi') ||
                type == 'counter_accepted_by_fundi' ||
                (job['status'] ?? '').toString() == 'counter_accepted' ||
                (job['counterAcceptedBy'] != null &&
                    (job['counterAcceptedBy'] as List).isNotEmpty &&
                    isBid);

            final reneg = (job['renegotiation'] as Map<String, dynamic>?) ?? {};
            final renegStatus = (reneg['status'] ?? '').toString();
            final jobStatus = (job['status'] ?? '').toString();
            final escrowStatus = (job['escrowStatus'] ?? '').toString();

            final isRenegCountered =
                renegStatus == 'countered_by_client' ||
                jobStatus == 'renegotiation_countered_by_client';
            final isRenegApprovedNeedsTopup =
                (renegStatus.contains('approved') ||
                    renegStatus == 'approved_pending_extra_escrow') &&
                (_toBool(job['clientNeedsToTopup']) ||
                    jobStatus == 'awaiting_extra_escrow' ||
                    escrowStatus == 'pending_topup' ||
                    jobStatus.contains('awaiting_extra_escrow'));

            if (isCounterAccepted) {
              final acceptedAmt =
                  (g['agreedPrice'] ??
                          g['clientCounterAmount'] ??
                          job['agreedPrice'] ??
                          job['clientCounterAmount'] ??
                          0)
                      .toString();
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade400, width: 1.5),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Your counter offer of KES $acceptedAmt has been accepted',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.green.shade900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${g['fundiName']} • Tap to view & proceed',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.green,
                  ),
                  onTap: () async {
                    await onMarkRead(fundiKey);
                    if (!context.mounted) return;
                    final parentContext = context;
                    showModalBottomSheet(
                      context: parentContext,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (sheetContext) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (ctx, scrollCtrl) => Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Your counter accepted',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'KES $acceptedAmt',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.all(12),
                                child: PendingBidList(
                                  jobId: g['jobId'].toString(),
                                  job: job,
                                  filter: FilterType.all,
                                  userPos: null,
                                  parentContextForNav: parentContext,
                                  sheetContextForClose: sheetContext,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            if (isRenegCountered) {
              int extraLabor = _toInt(reneg['counterExtraLabor'] ?? 0);
              int extraToLock = _toInt(
                reneg['counterExtraToLock'] ??
                    extraLabor + (extraLabor * 0.05).round(),
              );
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade400, width: 1.5),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.sync_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'You countered extra KES $extraLabor - waiting for fundi to confirm',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.orange.shade900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Extra to lock KES $extraToLock • ${g['fundiName']}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.orange,
                  ),
                  onTap: () async {
                    await onMarkRead(fundiKey);
                    if (!context.mounted) return;
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
                  },
                ),
              );
            }

            // === FIX: FUNDI ACCEPTED YOUR EXTRA COUNTER ===
            if (isRenegApprovedNeedsTopup) {
              int approvedExtra = _toInt(
                reneg['approvedExtra'] ??
                    reneg['counterExtraLabor'] ??
                    job['extraTopupAmount'] ??
                    1000,
              );
              int approvedToLock = _toInt(
                reneg['approvedExtraToLock'] ??
                    reneg['counterExtraToLock'] ??
                    job['extraTopupToLock'] ??
                    approvedExtra + (approvedExtra * 0.05).round(),
              );
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade600, width: 1.5),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_open,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Fundi accepted KES $approvedExtra - Lock extra KES $approvedToLock',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${g['fundiName']} accepted your counter • Tap to lock escrow',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'KES $approvedToLock',
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  onTap: () async {
                    await onMarkRead(fundiKey);
                    if (!context.mounted) return;
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
                  },
                ),
              );
            }

            if (isBid) {
              final bidCount = (g['bidCount'] ?? 1) as int;
              return Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBE6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FundipapColors.primaryYellow,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: FundipapColors.blackGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.gavel,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (badgeCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
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
                    bidCount == 1
                        ? 'You have a new bid for ${g['category']}'
                        : 'You have $bidCount new bids for ${g['category']}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${g['fundiName']} • Tap to view bids',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    await onMarkRead(fundiKey);
                    if (!context.mounted) return;
                    final parentContext = context;
                    showModalBottomSheet(
                      context: parentContext,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (sheetContext) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (ctx, scrollCtrl) => Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Bids for ${g['category']}',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FundipapColors.primaryYellow,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$bidCount ${bidCount == 1 ? 'bid' : 'bids'}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.all(12),
                                child: PendingBidList(
                                  jobId: g['jobId'].toString(),
                                  job: job,
                                  filter: FilterType.all,
                                  userPos: null,
                                  parentContextForNav: parentContext,
                                  sheetContextForClose: sheetContext,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }

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
