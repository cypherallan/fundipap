import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../widgets/timeline_card.dart';
import '../widgets/chat_sheet.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../fundi_customer_timeline_page.dart';

Widget buildCancelledView(BuildContext context, FundiTimelineContext c) {
  String title;
  String message;
  switch (c.status) {
    case 'cancelled_before_payment':
      title = 'Client cancelled';
      message = 'Client cancelled this job before paying to escrow.';
      break;
    case 'auto_cancelled_no_arrival':
      title = 'Auto-cancelled - No arrival - No payout';
      message = 'You did not arrive in time. Client got full refund.';
      break;
    case 'cancelled_after_arrival':
      title = 'Cancelled after arrival - Transport KES ${c.transport} to you';
      message =
          'Cancelled by ${c.job['cancelledBy'] ?? ''} - Reason: ${c.job['cancelReason'] ?? ''}';
      break;
    default:
      title = 'Cancelled - Full refund to client';
      message =
          'Cancelled by ${c.job['cancelledBy'] ?? ''} - Reason: ${c.job['cancelReason'] ?? ''}';
  }

  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 2),
      ),
      title: Text(
        c.clientName,
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
      ),
      backgroundColor: FundipapColors.blackGray,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () => openChatSheet(context, c.jobId, c.clientName),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        fundiCard(
          color: Colors.red.shade50,
          border: Colors.red,
          icon: Icons.cancel,
          iconColor: Colors.red,
          title: title,
          message: message,
          time: 'Now',
        ),
        FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('jobs')
              .where('repostedFrom', isEqualTo: c.jobId)
              .where(
                'status',
                whereIn: [
                  'open',
                  'assigned',
                  'confirmed',
                  'travelling',
                  'site_visit',
                  'in_progress',
                ],
              )
              .limit(1)
              .get(),
          builder: (ctx, repSnap) {
            if (!repSnap.hasData || repSnap.data!.docs.isEmpty)
              return const SizedBox();
            var newDoc = repSnap.data!.docs.first;
            return Card(
              color: Colors.green.shade50,
              child: ListTile(
                title: Text(
                  'Client reposted this job',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  'New job is open for bidding again',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                trailing: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FundiCustomerTimelinePage(
                        jobId: newDoc.id,
                        clientName: c.clientName,
                        jobTitle: c.jobTitle,
                      ),
                    ),
                  ),
                  child: const Text('VIEW NEW JOB'),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}
