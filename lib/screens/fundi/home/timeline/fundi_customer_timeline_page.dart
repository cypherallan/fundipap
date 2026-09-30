import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import 'fundi_timeline_context.dart';
import 'fundi_timeline_actions.dart';
import 'widgets/chat_sheet.dart';
import 'widgets/cancel_button.dart';
import 'widgets/timeline_card.dart';
import 'steps/cancelled_view.dart';
import 'steps/completed_released_view.dart';
import 'steps/escrow_waiting_view.dart';
import 'steps/parts_steps.dart';
import 'steps/counter_step.dart';
import 'steps/extra_escrow_step.dart';
import 'steps/site_visit_steps.dart';
import 'steps/work_steps.dart';
import 'steps/history_steps.dart';
import 'steps/bid_sent_view.dart';

class FundiCustomerTimelinePage extends StatelessWidget {
  final String jobId;
  final String clientName;
  final String jobTitle;
  const FundiCustomerTimelinePage({
    super.key,
    required this.jobId,
    required this.clientName,
    required this.jobTitle,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        final job = (snap.data!.data() as Map<String, dynamic>?) ?? {};
        final c = FundiTimelineContext.fromSnapshot(
          context: context,
          jobId: jobId,
          clientName: clientName,
          jobTitle: jobTitle,
          job: job,
        );

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .collection('bids')
              .doc(uid)
              .snapshots(),
          builder: (context, bidSnap) {
            bool hasBid = bidSnap.hasData && (bidSnap.data?.exists ?? false);
            int bidAmount = 0;
            if (hasBid) {
              var b = bidSnap.data!.data() as Map<String, dynamic>?;
              bidAmount =
                  int.tryParse(
                    (b?['amount'] ?? b?['bidAmount'] ?? 0).toString(),
                  ) ??
                  0;
            }
            var bidData = bidSnap.data?.data() as Map<String, dynamic>?;
            String bidStatus = (bidData?['status'] ?? '').toString();
            int acceptedAmt =
                int.tryParse(
                  (bidData?['agreedPrice'] ?? bidData?['price'] ?? bidAmount)
                      .toString(),
                ) ??
                bidAmount;

            if (c.isCancelled) return buildCancelledView(context, c);
            if (c.status == 'completed' && c.escrowReleased)
              return buildCompletedReleasedView(context, c);

            bool isBidSentState =
                hasBid &&
                !c.escrowDone &&
                (c.status == 'open' ||
                    c.status == 'pending' ||
                    c.status == 'bidding' ||
                    c.status == 'bid_sent' ||
                    c.status == 'pending_client_response');
            if (isBidSentState || c.isBidSent)
              return buildBidSentView(context, c, bidAmount);

            List<Widget> timeline = [];
            bool isCounterAccepted =
                bidStatus == 'counter_accepted_by_fundi' ||
                c.status == 'counter_accepted';

            if (isCounterAccepted) {
              // THIS IS NOW A TIMELINE ROW, NOT A FULL SCREEN
              timeline.add(
                fundiCard(
                  color: Colors.orange.shade50,
                  border: Colors.orange,
                  icon: Icons.hourglass_top,
                  iconColor: Colors.orange.shade800,
                  title: 'Accepted counter bid - KES $acceptedAmt',
                  message:
                      'You accepted KES $acceptedAmt. Waiting for client to confirm and lock escrow. You will receive KES ${c.fundiReceives}.',
                  time: 'Waiting',
                  isDone: false,
                ),
              );
              timeline.add(
                fundiCard(
                  color: Colors.green.shade50,
                  border: Colors.green,
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  title: 'Counter accepted KES $acceptedAmt - Done',
                  message: 'Done',
                  time: 'Just now',
                  isDone: true,
                ),
              );
              timeline.add(
                fundiCard(
                  color: Colors.green.shade50,
                  border: Colors.green,
                  icon: Icons.send,
                  iconColor: Colors.green,
                  title: 'Bid sent - Done KES $bidAmount',
                  message: 'Original bid',
                  time: 'Earlier',
                  isDone: true,
                ),
              );
            } else {
              if (!c.escrowDone)
                return buildEscrowWaitingView(
                  context,
                  c,
                  timeline,
                  bidAmount: bidAmount,
                  hasBid: hasBid,
                );
              if (handleCounterStep(timeline, c)) {
              } else if (handleExtraEscrowStep(timeline, c)) {
              } else if (handlePartsSteps(timeline, c)) {
              } else {
                handleWorkSteps(timeline, c);
                handleSiteVisitSteps(timeline, c);
              }
              addHistoryCards(
                timeline,
                c,
                bidAmount: bidAmount,
                hasBid: hasBid,
              );
            }

            Widget list = ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: timeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => timeline[i],
            );

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      FundiTimelineActions.goBackToMyJobs(context, tab: 2),
                ),
                title: Text(
                  clientName,
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
                backgroundColor: FundipapColors.blackGray,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () => openChatSheet(context, jobId, clientName),
                  ),
                ],
              ),
              body: c.canFundiCancel
                  ? Column(
                      children: [
                        Expanded(child: list),
                        fixedCancelBtn(context, jobId, job),
                      ],
                    )
                  : list,
            );
          },
        );
      },
    );
  }
}
