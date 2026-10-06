import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animated_waiting_card.dart';
import '../timeline/customer_fundi_timeline_page.dart';
import '../../confirm/approval/client_price_approval_screen.dart';
import '../../tracking/customer_tracking_screen.dart';
import '../helpers/customer_home_utils.dart';

Widget timelineCard({
  required String title,
  required String body,
  required IconData icon,
  bool isDone = false,
  Widget? action,
  Widget? extra,
}) {
  return Card(
    color: isDone ? Colors.green.shade50 : Colors.white,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: isDone ? Colors.green : Colors.transparent,
        width: 1.5,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isDone)
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
              if (isDone) const SizedBox(width: 6),
              Icon(
                icon,
                size: 18,
                color: isDone ? Colors.green : Colors.black87,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDone ? Colors.green.shade800 : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.inter(fontSize: 11)),
          if (extra != null) ...[const SizedBox(height: 6), extra],
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    ),
  );
}

bool _hasParts(Map<String, dynamic>? renego) {
  if (renego == null) return false;
  var list = renego['partsNeeded'] as List?;
  if (list != null && list.isNotEmpty) return true;
  int est = toInt(renego['partsEstimateTotal']);
  int total = toInt(renego['totalPartsEstimate']);
  String till = (renego['tillNumber'] ?? '').toString().trim();
  return est > 0 || total > 0 || till.isNotEmpty;
}

class HomeStatusWidget extends StatelessWidget {
  final Map<String, dynamic> job;
  final BuildContext parentContext;
  const HomeStatusWidget({
    super.key,
    required this.job,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    var escrow = (job['escrowStatus'] ?? 'pending').toString();
    var status = (job['status'] ?? '').toString();
    bool siteDone = toBool(job['siteVisitDone']) || toBool(job['siteVisited']);
    bool isTravelling =
        toBool(job['travelling']) &&
        toBool(job['siteVisitStarted']) &&
        !siteDone;
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    String renegStatus = (reneg?['status'] ?? '').toString();
    String phase = (reneg?['currentPhase'] ?? '').toString();

    // FIX: Cover all extra escrow statuses
    bool needsExtraEscrow =
        renegStatus.contains('pending_extra_escrow') ||
        renegStatus.contains('extra_pending_escrow') ||
        status == 'awaiting_extra_escrow' ||
        status == 'awaiting_extra_payment';

    int labour = toInt(
      job['laborCost'] ?? job['agreedPrice'] ?? job['acceptedBidAmount'] ?? 0,
    );
    int transport = toInt(job['transportFee'] ?? 0);
    int clientAppFee = toInt(job['clientAppFee'] ?? (labour * 0.05).round());
    int totalToPay = toInt(
      job['totalClientPays'] ??
          job['totalCost'] ??
          labour + transport + clientAppFee,
    );
    int alreadyLocked = toInt(job['escrowAmount'] ?? 0);
    bool escrowHeldFlag =
        toBool(job['escrowHeld']) || job['escrowPaidAt'] != null;
    bool escrowDone =
        ['held', 'paid', 'released'].contains(escrow) ||
        escrowHeldFlag ||
        alreadyLocked > 0 ||
        status == 'escrow_locked' ||
        status == 'completed';
    String jobId = (job['jobId'] ?? job['id'] ?? '').toString();

    if (status == 'completed') {
      return timelineCard(
        title: 'Job completed - Done',
        body: 'KES $alreadyLocked released to fundi',
        icon: Icons.check_circle,
        isDone: true,
      );
    }

    if (!escrowDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrangeAnimatedWaitingCard(
            title: 'Waiting: Lock KES $totalToPay to escrow now',
            message:
                'Fundi confirmed. You need to pay to escrow to start the job.',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.primaryYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => payEscrow(jobId, totalToPay.toDouble()),
              child: Text(
                'Pay KES $totalToPay to Escrow',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Travelling states
    if (!isTravelling &&
        !siteDone &&
        status != 'site_visit' &&
        status != 'in_progress' &&
        !status.contains('completed') &&
        status != 'awaiting_extra_escrow' &&
        status != 'waiting_for_client_to_buy_parts' &&
        status != 'fundi_buying_parts' &&
        phase != 'fundi_working' &&
        phase != 'waiting_for_client_to_buy_parts' &&
        phase != 'fundi_buying_parts' &&
        !needsExtraEscrow) {
      return OrangeAnimatedWaitingCard(
        title: 'Waiting for fundi to start travelling',
        message:
            'Escrow KES $alreadyLocked secured. ${job['assignedFundiName'] ?? 'Fundi'} has NOT started travelling yet.',
      );
    }

    if (isTravelling && !siteDone) {
      return OrangeAnimatedWaitingCard(
        title: 'Fundi is on the way - Waiting to arrive',
        message:
            '${job['assignedFundiName'] ?? 'Fundi'} is travelling to your location. Tracking live.',
        onTap: () => Navigator.push(
          parentContext,
          MaterialPageRoute(
            builder: (_) => CustomerTrackingScreen(jobId: jobId, job: job),
          ),
        ),
      );
    }

    // FIX: Show lock extra after price preview
    if (needsExtraEscrow) {
      int counterExtra = toInt(
        reneg?['acceptedCounterExtraLabor'] ?? reneg?['counterExtraLabor'] ?? 0,
      );
      int extraToLock = toInt(
        reneg?['acceptedCounterExtraToLock'] ??
            reneg?['counterExtraToLock'] ??
            reneg?['extraToLock'] ??
            0,
      );
      if (extraToLock == 0) {
        int newTotal = toInt(reneg?['newTotalClientPays'] ?? 0);
        if (newTotal > 0) extraToLock = newTotal - alreadyLocked;
      }
      bool isCounterAccepted = counterExtra > 0;
      return OrangeAnimatedWaitingCard(
        title: isCounterAccepted
            ? 'Fundi accepted your counter KES $counterExtra - Lock extra KES $extraToLock'
            : 'Lock extra KES $extraToLock in escrow',
        message: isCounterAccepted
            ? 'Fundi accepted your counter request of KES $counterExtra. Proceed to lock KES $extraToLock before fundi continues.'
            : 'You accepted new price. Lock extra KES $extraToLock before fundi continues.',
      );
    }

    if (reneg != null &&
        toBool(reneg['requested']) &&
        renegStatus == 'pending') {
      return OrangeAnimatedWaitingCard(
        title: 'Fundi requests price review - Waiting for you',
        message:
            '${reneg['reasonDetails'] ?? 'Fundi sent new breakdown'} - Tap to REVIEW BREAKDOWN.',
        onTap: () => Navigator.push(
          parentContext,
          MaterialPageRoute(
            builder: (_) => ClientPriceApprovalScreen(jobId: jobId, job: job),
          ),
        ),
      );
    }

    bool hasParts = _hasParts(reneg);

    // Parts flow - only if hasParts
    if (phase == 'waiting_for_client_to_buy_parts' && hasParts) {
      return const OrangeAnimatedWaitingCard(
        title: 'You will buy parts - Confirm when bought',
        message: 'Extra locked. Buy the listed parts then confirm.',
      );
    }
    if (phase == 'client_claims_parts_bought' && hasParts) {
      return const OrangeAnimatedWaitingCard(
        title: 'Parts bought - Waiting for fundi to confirm',
        message: 'You marked parts as bought. Waiting for fundi to confirm.',
      );
    }
    if (phase == 'parts_confirmed_by_fundi' && hasParts) {
      return const OrangeAnimatedWaitingCard(
        title: 'Fundi confirmed parts - Waiting to start work',
        message:
            'Fundi confirmed parts are available. Waiting for him to tap Start Job.',
      );
    }

    // FIX: After locking extra with NO parts, show waiting for fundi to start job
    bool isSiteVisitPhase =
        status == 'site_visit' ||
        phase == 'waiting_for_client_to_buy_parts' ||
        phase == 'fundi_buying_parts' ||
        phase == 'client_claims_parts_bought' ||
        phase == 'parts_confirmed_by_fundi';

    if (isSiteVisitPhase) {
      // If hasParts is false, skip parts and show waiting for fundi to start
      if (!hasParts) {
        return const OrangeAnimatedWaitingCard(
          title: 'Waiting for fundi to start job',
          message:
              'Extra labour locked. Fundi will start working now - no parts needed.',
        );
      }
      // If hasParts true but we are already past parts, still show waiting for fundi
      if (phase == 'parts_confirmed_by_fundi' || phase.isEmpty) {
        return const OrangeAnimatedWaitingCard(
          title: 'Waiting for fundi to start job',
          message:
              'Fundi arrived at your location and is on site. Waiting for him to Start Job.',
        );
      }
    }

    if (phase == 'fundi_working' || status == 'in_progress') {
      return const OrangeAnimatedWaitingCard(
        title: 'Fundi is working - Waiting to complete',
        message:
            'Job in progress. Waiting for fundi to tap MARK JOB AS COMPLETED.',
      );
    }
    if (status == 'job_completed' || status == 'pending_completion') {
      int newLabour = toInt(
        reneg?['newLaborTotal'] ?? labour + toInt(reneg?['extraLabor'] ?? 0),
      );
      int newClientFee = (newLabour * 0.05).round();
      int newTotal = newLabour + transport + newClientFee;
      int totalToRelease = toInt(reneg?['newTotalClientPays'] ?? newTotal);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrangeAnimatedWaitingCard(
            title:
                'Job Completed - Waiting for you to confirm & release KES $totalToRelease',
            message:
                'Fundi marked job as complete. Waiting for you to confirm and release KES $totalToRelease.',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.greenSuccess,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.push(
                parentContext,
                MaterialPageRoute(
                  builder: (_) => CustomerFundiTimelinePage(
                    jobId: jobId,
                    fundiName: job['assignedFundiName'] ?? 'Fundi',
                    trade: job['category'] ?? '',
                    jobData: job,
                  ),
                ),
              ),
              child: Text(
                'CONFIRM & RELEASE KES $totalToRelease',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return timelineCard(
      title: 'Bid accepted - Escrow locked KES $alreadyLocked',
      body: 'Escrow secured. Waiting for fundi to travel.',
      icon: Icons.verified,
      isDone: true,
    );
  }
}
