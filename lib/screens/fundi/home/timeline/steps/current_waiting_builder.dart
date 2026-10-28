import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../../services/fundi_waiting_state_service.dart';
import '../core/timeline_utils.dart';
import '../widgets/fundi_status_card.dart';
import '../fundi_timeline_actions.dart';
import '../../fundi_visit_customer_tab.dart';
import '../../../new_price_request/fundi_request_new_price_screen.dart';

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
  bool hasParts = hasPartsInRenego(renego);
  String renegoStatus = (renego?['status'] ?? '').toString().toLowerCase();
  bool isRejected =
      renegoStatus == 'rejected' || job['hasClientRejected'] == true;
  bool canDispute = job['fundiCanDispute'] == true;

  // === FIX 4: NEW FLOW - rejected_continued_old_price ===
  // Client rejected extra (e.g., 1 socket vs 8). Fundi continues NOW with old price, ONLY original client photos.
  if (renegoStatus.contains('rejected_continued_old_price')) {
    int extraRequested = toInt(
      renego?['extraLaborRequested'] ??
          renego?['extraLabor'] ??
          renego?['requestedExtra'] ??
          0,
    );
    int oldPrice = toInt(
      job['agreedPrice'] ?? job['originalLaborCost'] ?? job['laborCost'] ?? 0,
    );
    String rejectionLabel =
        (renego?['rejectionLabel'] ??
                renego?['rejectedReason'] ??
                'Client rejected extra')
            .toString();
    String rejectionCode = (renego?['rejectionCode'] ?? renego?['code'] ?? '')
        .toString();
    String customText = (renego?['rejectionCustomText'] ?? '').toString();

    IconData reasonIcon = Icons.info_outline;
    String instruction =
        'DO ONLY what was in client ORIGINAL photos. Example: 1 socket only, NOT 8.';
    if (rejectionCode == 'only_original') {
      reasonIcon = Icons.photo_library_outlined;
      instruction =
          'Client: Do ONLY original scope from my posted photos (e.g., 1 socket). Extra work will be posted later as new job.';
    } else if (rejectionCode == 'photos_not_genuine') {
      reasonIcon = Icons.report_problem_rounded;
      instruction =
          'Client flagged photos as not genuine. Continue OLD price with original photos only. Admin will review extra ticket separately.';
    } else if (rejectionCode == 'too_expensive') {
      instruction =
          'Client says too expensive. Continue OLD price, original scope only.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade600, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(reasonIcon, color: Colors.orange.shade900, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Client rejected extra - Continue OLD price KES $oldPrice',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reason: $rejectionLabel',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (customText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Details: $customText',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                ],
                if (extraRequested > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Extra rejected: KES $extraRequested',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Code: $rejectionCode',
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.task_alt, size: 16, color: Colors.blue.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    instruction,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.greenSuccess,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () => FundiTimelineActions.startJob(jobId),
              child: Text(
                'START / CONTINUE JOB - KES $oldPrice (OLD PRICE ONLY)',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (rejectionCode == 'photos_not_genuine') ...[
            const SizedBox(height: 8),
            Text(
              'This rejection created ticket in extra_disputes for admin. You still continue old job NOW. No waiting.',
              style: GoogleFonts.inter(fontSize: 9, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  // === CLIENT REJECTED NEW PRICE - SHOW IMMEDIATELY (OLD FLOW - legacy jobs) ===
  if (isRejected && canDispute) {
    int extraRequested = toInt(
      renego?['extraLaborRequested'] ?? renego?['extraLabor'] ?? 0,
    );
    int oldPrice = toInt(
      job['agreedPrice'] ?? job['originalLaborCost'] ?? job['laborCost'] ?? 0,
    );
    String rejectReason = (renego?['rejectedReason'] ?? 'No reason given')
        .toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Client rejected your new price request',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Client rejected extra KES $extraRequested. Reason: $rejectReason',
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'You can dispute if you are on site (photos verified) or continue with old price KES $oldPrice',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                int oldPriceInt = toInt(
                  job['agreedPrice'] ??
                      job['originalLaborCost'] ??
                      job['laborCost'] ??
                      0,
                );
                await FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .update({
                      'status': 'in_progress',
                      'renegotiation.status': 'rejected_continued_old_price',
                      'renegotiation.chose': 'continue_old_price_after_reject',
                      'renegotiation.choseAt': FieldValue.serverTimestamp(),
                      'renegotiation.extraLabor': 0,
                      'renegotiation.extraLaborRequested': 0,
                      'renegotiation.extraToLock': 0,
                      'renegotiation.pendingLabor': 0,
                      'renegotiation.agreedExtraLabor': 0,
                      'renegotiation.finalExtraLabor': 0,
                      'renegotiation.acceptedCounterExtraLabor': 0,
                      'extraLabor': 0,
                      'extraTopupAmount': 0,
                      'extraTopupToLock': 0,
                      'hasClientRejected': false,
                      'fundiCanDispute': false,
                      'escrowAmount': oldPriceInt,
                      'lockedEscrow': oldPriceInt,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
              },
              child: Text(
                'Continue with KES $oldPrice',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () async {
                try {
                  final uid = FirebaseAuth.instance.currentUser!.uid;
                  final clientId = (job['customerId'] ?? job['clientId'] ?? '')
                      .toString();

                  // Top-level disputes collection - same as admin panel listens to
                  await FirebaseFirestore.instance.collection('disputes').add({
                    'jobId': jobId,
                    'fundiId': uid,
                    'clientId': clientId,
                    'type': 'price_rejected_dispute',
                    'reason':
                        'Client rejected extra KES $extraRequested but I am on site - photos verified',
                    'extraRequested': extraRequested,
                    'oldPrice': oldPrice,
                    'status': 'open',
                    'trade': job['trade'] ?? job['category'] ?? '',
                    'disputedAmount': extraRequested,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  await FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(jobId)
                      .update({
                        'status': 'dispute_pending',
                        'renegotiation.status': 'disputed_by_fundi',
                        'hasClientRejected': false,
                        'fundiCanDispute': false,
                        'hasDispute': true,
                        'disputeRaisedBy': uid,
                        'disputeRaisedAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dispute raised - Admin will review'),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('DISPUTE ERROR: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: Text(
                'DISPUTE',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int origExtra = toInt(
    renego?['extraLabor'] ??
        renego?['extra'] ??
        renego?['extraLaborAmount'] ??
        job['extraLaborAmount'] ??
        0,
  );
  int counterExtra = toInt(
    renego?['counterExtraLabor'] ?? renego?['clientCounterExtraLabor'] ?? 0,
  );
  int agreedExtra = toInt(
    renego?['agreedExtraLabor'] ??
        renego?['acceptedCounterExtraLabor'] ??
        renego?['finalExtraLabor'] ??
        0,
  );
  int finalExtra = agreedExtra > 0
      ? agreedExtra
      : (counterExtra > 0 ? counterExtra : origExtra);
  int extraLabourToShow = finalExtra;

  int oldLaborRenego = toInt(renego?['oldLabor'] ?? renego?['oldLabour'] ?? 0);
  int currentLaborCost = toInt(job['laborCost'] ?? job['agreedPrice'] ?? 0);
  int agreed = toInt(job['agreedPrice'] ?? 0);
  int labour;
  if (currentLaborCost > 0) {
    labour = currentLaborCost;
  } else if (oldLaborRenego > 0) {
    labour = oldLaborRenego + finalExtra;
  } else {
    labour = agreed > 0
        ? agreed
        : toInt(job['originalLaborCost'] ?? job['price'] ?? 0);
  }

  int transport = toInt(job['transportFee'] ?? 0);
  int fundiCommissionPct = toInt(
    job['fundiCommissionPct'] ?? job['fundiFeePercent'] ?? 10,
  );
  int fundiAppFee = (labour * fundiCommissionPct / 100).round();
  int fundiReceives = labour + transport - fundiAppFee;

  if ((status == 'waiting_for_client_to_buy_parts' ||
          lowPhase == 'waiting_for_client_to_buy_parts' ||
          lowStat == 'waiting_for_client_to_buy_parts') &&
      !hasParts) {
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
                  extraLabourToShow > 0
                      ? 'Extra KES $extraLabourToShow approved - Continue with job'
                      : 'Site visited - Ready to start',
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
            extraLabourToShow > 0
                ? 'New labour KES $labour to earn (extra $extraLabourToShow). Tap START JOB.'
                : 'Labour KES $labour to earn. Tap START JOB.',
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
  }

  bool isClientBoughtPhase =
      (lowStat.contains('bought') ||
          lowPhase.contains('bought') ||
          lowStat == 'fundi_buying_parts' ||
          lowPhase == 'fundi_buying_parts' ||
          lowPhase == 'client_bought_materials' ||
          lowStat == 'client_claims_parts_bought' ||
          lowPhase == 'client_claims_parts_bought' ||
          lowPhase == 'awaiting_fundi_confirmation') &&
      hasParts;

  if (lowStat == 'pending_completion' ||
      lowStat == 'job_completed' ||
      lowPhase == 'completed_by_fundi' ||
      lowPhase == 'pending_completion') {
    return OrangeAnimatedWaitingCard(
      title: 'Job Completed - Waiting for $clientName to confirm',
      message:
          'You marked $jobTitle as completed. Waiting for $clientName to confirm and release KES $fundiReceives.',
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
              'You are working - Labour KES $labour - Will receive KES $fundiReceives',
          message:
              'You are working. Complete the job for client to release payment.',
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
  } else if ((status == 'waiting_for_client_to_buy_parts' ||
          renego?['currentPhase'] == 'waiting_for_client_to_buy_parts') &&
      hasParts) {
    return OrangeAnimatedWaitingCard(
      title: 'Waiting for client to buy materials',
      message: extraLabourToShow > 0
          ? 'Client approved extra KES $extraLabourToShow. Waiting for materials to start.'
          : 'Waiting for client to buy materials.',
    );
  }

  // === PRICE REVIEW DEADLOCK ===
  if (lowStat == 'price_review_deadlock' || renegoStatus.contains('deadlock')) {
    int oldLabor = toInt(
      renego?['oldLabor'] ?? job['agreedPrice'] ?? job['laborCost'] ?? 0,
    );
    int oldTransport = toInt(
      renego?['oldTransportFee'] ?? job['transportFee'] ?? 0,
    );
    int alreadyLocked = toInt(
      job['escrowAmount'] ?? job['totalClientPays'] ?? 0,
    );
    int extraRequested = toInt(
      renego?['extraLabor'] ?? renego?['counteredExtraRequested'] ?? 0,
    );
    int counterRound = toInt(renego?['counterRound'] ?? 3);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Price Review Deadlocked - Client refused extra',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Client countered 0 or <30% for $counterRound rounds. You requested extra KES $extraRequested. Old labour KES $oldLabor + transport $oldTransport already locked KES $alreadyLocked.',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.red.shade800),
          ),
          const SizedBox(height: 12),
          // Option 1: Continue old price
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .update({
                      'status': 'in_progress',
                      'renegotiation.status': 'fundi_continued_old_price',
                      'renegotiation.chose': 'continue_old_price',
                      'renegotiation.choseAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
              },
              child: Text(
                'Continue with old price KES $oldLabor',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Option 2: Withdraw with compensation - SECURE via function
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                var callable = FirebaseFunctions.instanceFor(
                  region: 'europe-west1',
                ).httpsCallable('resolveExtraRefusedDeadlock');
                await callable.call({
                  'jobId': jobId,
                  'action': 'withdraw_with_compensation',
                });
              },
              child: Text(
                'WITHDRAW',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Option 3: DISPUTE button - SECURE via function
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 52),
              ),
              onPressed: () async {
                var callable = FirebaseFunctions.instanceFor(
                  region: 'europe-west1',
                ).httpsCallable('resolveExtraRefusedDeadlock');
                await callable.call({
                  'jobId': jobId,
                  'action': 'dispute_to_admin',
                });
              },
              child: Text(
                'DISPUTE - EXTRA WORK REFUSED\nClient refused KES $extraRequested',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      int fallbackMyBid = toInt(
        job['originalLaborCost'] ??
            job['agreedPrice'] ??
            job['laborCost'] ??
            myBidPrice ??
            0,
      );
      int displayMyBid = isRenegoCounter && myExtraBid > 0
          ? myExtraBid
          : fallbackMyBid;
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
                          renego['oldLabor'] ??
                              job['originalLaborCost'] ??
                              job['agreedPrice'] ??
                              job['laborCost'] ??
                              0,
                        );
                        int approvedExtra = toInt(
                          renego['counterExtraLabor'] ?? 0,
                        );
                        int clientPct = toInt(job['clientCommissionPct'] ?? 5);
                        int approvedExtraToLock = toInt(
                          renego['counterExtraToLock'] ??
                              (approvedExtra +
                                  (approvedExtra * clientPct / 100).round()),
                        );
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
                                  (approvedExtra * clientPct / 100).round(),
                              'renegotiation.requested': false,
                              'renegotiation.oldLabor': currentAgreed,
                              'renegotiation.newLaborTotal':
                                  currentAgreed + approvedExtra,
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
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(jobId)
                  .update({
                    'status': 'travelling',
                    'travelling': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitCustomerScreen(jobId: jobId, job: job),
                ),
              );
            },
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
                    'Site visited - Ready to start work',
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
              'Labour KES $labour • Tap START JOB.',
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
                    'You are working - Labour KES $labour',
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
        title: 'Job Completed - Waiting for client',
        message:
            'Waiting for client to confirm and release KES $fundiReceives.',
      );
    case FundiWaitingType.priceReviewDeadlock:
      int oldLabor = toInt(job['agreedPrice'] ?? job['laborCost'] ?? 0);
      return OrangeAnimatedWaitingCard(
        title: 'Deadlock - Client refused extra',
        message:
            'Client refused extra. Choose to continue old price KES $oldLabor or withdraw',
      );
    case FundiWaitingType.priceRejected:
      return null;
  }
}
