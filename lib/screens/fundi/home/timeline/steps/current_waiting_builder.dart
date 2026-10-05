import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../../../../services/fundi_waiting_state_service.dart';
import '../core/timeline_utils.dart';
import '../widgets/fundi_status_card.dart';
import '../fundi_timeline_actions.dart';
import '../../fundi_visit_customer_tab.dart';
import '../../../my_jobs/fundi_request_new_price_screen.dart';

Widget? buildCurrentWaiting({
  required BuildContext context,
  required Map<String, dynamic> job,
  required String jobId,
  required String jobTitle,
  required String clientName,
  required String status,
  required int fundiSees,
  required DocumentReference bidRef,
  required int myBidPrice,
  required FundiWaitingState? waitingState,
  required Future<void> Function(
    BuildContext,
    DocumentReference,
    String,
    double,
  )
  counterAsFundi,
}) {
  final renego = job['renegotiation'] as Map<String, dynamic>?;
  String lowStat = (job['status'] ?? '').toString().toLowerCase();
  String lowPhase = (renego?['currentPhase'] ?? '').toString().toLowerCase();
  bool isClientBoughtPhase =
      lowStat.contains('bought') ||
      lowPhase.contains('bought') ||
      lowStat == 'fundi_buying_parts' ||
      lowPhase == 'fundi_buying_parts' ||
      lowPhase == 'client_bought_materials' ||
      lowStat == 'client_claims_parts_bought' ||
      lowPhase == 'client_claims_parts_bought' ||
      lowPhase == 'awaiting_fundi_confirmation';

  // OVERRIDE 1 - SAME ORDER AS ORIGINAL
  if (lowStat == 'pending_completion' ||
      lowStat == 'job_completed' ||
      lowPhase == 'completed_by_fundi' ||
      lowPhase == 'pending_completion') {
    return OrangeAnimatedWaitingCard(
      title: 'Job Completed - Waiting for $clientName to confirm',
      message:
          'You marked $jobTitle as completed. Waiting for $clientName to confirm and release payment.',
    );
  } else if (lowStat == 'in_progress' ||
      lowStat == 'fundi_working' ||
      lowPhase == 'fundi_working' ||
      lowPhase == 'in_progress') {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrangeAnimatedWaitingCard(
          title:
              'You are working - KES ${toInt(job['agreedPrice'] ?? job['laborCost'] ?? 6000)}',
          message: 'You are working on $jobTitle.',
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.greenSuccess,
              minimumSize: const Size(double.infinity, 52),
            ),
            onPressed: () => FundiTimelineActions.completeJob(jobId),
            child: const Text(
              'MARK JOB AS COMPLETED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  } else if (isClientBoughtPhase) {
    return fundiCard(
      color: Colors.blue.shade50,
      border: Colors.blue,
      icon: Icons.inventory,
      iconColor: Colors.blue.shade800,
      title: 'Client says materials bought',
      message: 'Client bought parts. Confirm to show START WORK.',
      time: 'Now',
      isCurrent: true,
      action: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          minimumSize: const Size(double.infinity, 52),
        ),
        onPressed: () => FundiTimelineActions.confirmPartsAvailable(jobId),
        child: const Text(
          'CONFIRM MATERIALS AVAILABLE',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  } else if (status == 'waiting_for_client_to_buy_parts' ||
      renego?['currentPhase'] == 'waiting_for_client_to_buy_parts') {
    return OrangeAnimatedWaitingCard(
      title: 'Waiting for client to buy materials',
      message:
          'Client locked extra labour KES ${toInt(renego?['acceptedCounterExtraLabor'] ?? 1000)} (counter ${toInt(renego?['counterExtraLabor'] ?? 1000)} accepted). Total locked KES ${toInt(job['agreedPrice'] ?? 6000)} labour. Waiting for materials.',
    );
  }

  // WAITING STATE SWITCH - ORIGINAL SWITCH PRESERVED 100%
  if (waitingState == null) return null;
  switch (waitingState.type) {
    case FundiWaitingType.clientCounter:
      int clientCounterAmt = waitingState.price;
      final bool isRenegoCounter =
          renego != null &&
          (renego['status'] == 'countered_by_client' ||
              renego['status'] == 'countered');
      int myExtraBid = toInt(
        renego?['counteredExtraRequested'] ?? renego?['extraLabor'] ?? 0,
      );
      int clientExtraCounter = toInt(renego?['counterExtraLabor'] ?? 0);
      int displayClientAmt = isRenegoCounter && clientExtraCounter > 0
          ? clientExtraCounter
          : clientCounterAmt;
      int displayMyBid = isRenegoCounter && myExtraBid > 0
          ? myExtraBid
          : myBidPrice;
      String uid = FirebaseAuth.instance.currentUser!.uid;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRenegoCounter
                        ? 'Client countered your extra labour'
                        : 'Client countered your labour charges',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Client countered: KES $displayClientAmt (Your bid KES $displayMyBid)',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (isRenegoCounter) {
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(jobId)
                            .update({
                              'renegotiation.status': 'rejected_by_fundi',
                              'renegotiation.rejectedAt':
                                  FieldValue.serverTimestamp(),
                            });
                      } else {
                        await bidRef.update({
                          'status': 'rejected',
                          'rejectedBy': uid,
                          'rejectedAt': FieldValue.serverTimestamp(),
                        });
                      }
                    },
                    child: Text(
                      'Reject',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => counterAsFundi(
                      context,
                      bidRef,
                      jobId,
                      displayClientAmt.toDouble(),
                    ),
                    child: Text(
                      'Counter',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.greenSuccess,
                    ),
                    onPressed: () async {
                      if (isRenegoCounter) {
                        int currentAgreed = toInt(
                          job['agreedPrice'] ??
                              job['laborCost'] ??
                              job['price'] ??
                              5000,
                        );
                        if (currentAgreed > 6000) {
                          int lastCorrectLock = toInt(
                            job['renegotiation']?['oldTotalClientPays'] ?? 5350,
                          );
                          int lastTrans = toInt(job['transportFee'] ?? 100);
                          int calcOldLab =
                              ((lastCorrectLock - lastTrans) / 1.05).round();
                          if (calcOldLab > 0 && calcOldLab < currentAgreed)
                            currentAgreed = calcOldLab;
                        }
                        int approvedExtra = toInt(
                          renego['counterExtraLabor'] ?? 0,
                        );
                        int approvedExtraToLock = toInt(
                          renego['counterExtraToLock'] ??
                              (approvedExtra * 1.05).round(),
                        );
                        int oldTrans = toInt(
                          job['transportFee'] ??
                              renego['oldTransportFee'] ??
                              100,
                        );
                        int newLabour = currentAgreed + approvedExtra;
                        int newTotalPay =
                            newLabour + oldTrans + (newLabour * 0.05).round();
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(jobId)
                            .update({
                              'renegotiation.status':
                                  'approved_pending_extra_escrow',
                              'renegotiation.approvedAt':
                                  FieldValue.serverTimestamp(),
                              'renegotiation.approvedExtra': approvedExtra,
                              'renegotiation.approvedExtraToLock':
                                  approvedExtraToLock,
                              'renegotiation.acceptedCounterExtraLabor':
                                  approvedExtra,
                              'renegotiation.acceptedCounterExtraToLock':
                                  approvedExtraToLock,
                              'renegotiation.acceptedCounterExtraAppFee':
                                  (approvedExtra * 0.05).round(),
                              'renegotiation.requested': false,
                              'renegotiation.oldLabor': currentAgreed,
                              'renegotiation.newLaborTotal': newLabour,
                              'renegotiation.newTotalClientPays': newTotalPay,
                              'laborCost': newLabour,
                              'agreedPrice': newLabour,
                              'totalClientPays': newTotalPay,
                              'extraTopupAmount': approvedExtra,
                              'extraTopupToLock': approvedExtraToLock,
                              'status': 'awaiting_extra_escrow',
                              'escrowStatus': 'pending_topup',
                              'clientNeedsToTopup': true,
                              'customerHasUnread': true,
                              'fundiHasUnread': false,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        String clientId =
                            (job['clientId'] ??
                                    job['customerId'] ??
                                    job['userId'] ??
                                    '')
                                .toString();
                        if (clientId.isNotEmpty) {
                          await FirebaseFirestore.instance
                              .collection('notifications')
                              .add({
                                'jobId': jobId,
                                'toUserId': clientId,
                                'type': 'renegotiation_approved',
                                'title':
                                    'Fundi accepted counter KES $approvedExtra',
                                'message':
                                    'Please lock extra KES $approvedExtraToLock to escrow',
                                'createdAt': FieldValue.serverTimestamp(),
                                'read': false,
                              });
                        }
                      } else {
                        var myUid = FirebaseAuth.instance.currentUser!.uid;
                        var userSnap = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(myUid)
                            .get();
                        String fundiName =
                            (userSnap.data()?['username'] ?? 'Fundi')
                                .toString();
                        await bidRef.update({
                          'status': 'counter_accepted_by_fundi',
                          'agreedPrice': clientCounterAmt,
                          'price': clientCounterAmt,
                          'acceptedAt': FieldValue.serverTimestamp(),
                        });
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(jobId)
                            .update({
                              'status': 'counter_accepted',
                              'counterAcceptedBy': FieldValue.arrayUnion([
                                myUid,
                              ]),
                              'lastCounterAcceptedBy': myUid,
                              'lastCounterAcceptedByName': fundiName,
                              'agreedPrice': clientCounterAmt,
                              'lastCounterAmount': clientCounterAmt,
                              'counterAcceptedBids': FieldValue.arrayUnion([
                                bidRef.id,
                              ]),
                              'customerHasUnread': true,
                              'clientHasUnread': true,
                              'customerUnreadType': 'counter_accepted',
                              'updatedAt': FieldValue.serverTimestamp(),
                              'priceHistory': FieldValue.arrayUnion([
                                {
                                  'price': clientCounterAmt,
                                  'by': myUid,
                                  'type': 'accepted_client_counter',
                                  'at': DateTime.now().toIso8601String(),
                                },
                              ]),
                            });
                      }
                    },
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    case FundiWaitingType.bidSent:
    case FundiWaitingType.myCounter:
    case FundiWaitingType.waitingEscrow:
    case FundiWaitingType.waitingNewPriceApproval:
      return OrangeAnimatedWaitingCard(
        title: waitingState.title,
        message: waitingState.message,
      );
    case FundiWaitingType.escrowLocked:
      return fundiCard(
        color: Colors.white,
        border: FundipapColors.blackGray,
        icon: Icons.location_on,
        iconColor: Colors.black,
        title: waitingState.title,
        message: waitingState.message,
        time: 'Now',
        isCurrent: true,
        action: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
            icon: const Icon(Icons.navigation),
            label: const Text('START SITE VISIT'),
            onPressed: () =>
                FundiTimelineActions.startSiteVisit(context, jobId, jobTitle),
          ),
        ),
      );
    case FundiWaitingType.travelling:
      return fundiCard(
        color: Colors.blue.shade50,
        border: Colors.blue,
        icon: Icons.directions_bike,
        iconColor: Colors.blue,
        title: 'You are on the way',
        message: 'Travelling to client - open tracking',
        time: 'Now',
        isCurrent: true,
        action: ElevatedButton.icon(
          icon: const Icon(Icons.map),
          label: const Text('OPEN TRACKING'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitCustomerScreen(jobId: jobId, job: job),
            ),
          ),
        ),
      );
    case FundiWaitingType.siteVisited:
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade400, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Waiting for you to start work - KES $fundiSees',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'You visited site. Client locked KES $fundiSees secured. Tap START JOB to begin.',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => FundiTimelineActions.startJob(jobId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.greenSuccess,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text(
                      'START JOB',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FundiRequestNewPriceScreen(jobId: jobId, job: job),
                      ),
                    ),
                    child: const Text('New Price'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    case FundiWaitingType.working:
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade400, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.construction, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are working - KES ${waitingState.price}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'You are working on $jobTitle. Tap to mark completed.',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.greenSuccess,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: () => FundiTimelineActions.completeJob(jobId),
                child: const Text(
                  'MARK JOB AS COMPLETED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    case FundiWaitingType.jobCompleted:
      return OrangeAnimatedWaitingCard(
        title: 'Job Completed - Waiting for $clientName to confirm',
        message:
            'You marked $jobTitle as completed. Waiting for $clientName to confirm and release payment.',
      );
  }
}
