import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../../confirm/client_price_approval_screen.dart';
import '../timeline_actions.dart';
import '../timeline_utils.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class RenegotiationSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    // === FIX: you countered extra labour - show waiting for fundi to confirm, not start job ===
    if (c.reneg != null &&
        ((c.renegStatus == 'countered_by_client') ||
            (c.job['status'] ?? '').toString() ==
                'renegotiation_countered_by_client')) {
      int extraLabor = toInt(c.reneg!['counterExtraLabor'] ?? 0);
      int extraToLock = toInt(
        c.reneg!['counterExtraToLock'] ??
            extraLabor + (extraLabor * 0.05).round(),
      );
      int extraRequested = toInt(
        c.reneg!['counteredExtraRequested'] ?? c.reneg!['extraLabor'] ?? 0,
      );

      timeline.add(
        TimelineCard(
          title:
              'You countered extra KES $extraLabor - waiting for fundi to confirm',
          body:
              'Fundi requested extra KES $extraRequested • You offered KES $extraLabor (KES $extraToLock with 5% fee)\nWaiting for ${c.fundiName} to confirm your counter offer',
          icon: Icons.hourglass_top,
          isDone: false,
        ),
      );
      // also show orange waiting animation
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Waiting for fundi to confirm extra labour counter',
          message:
              'You countered KES $extraRequested with KES $extraLabor (KES $extraToLock to lock). Fundi will accept or counter back.',
        ),
      );
      return true;
    }

    if (c.needsExtraEscrow) {
      int extraToLock = toInt(
        c.reneg?['extraToLock'] ?? toInt(c.job['extraToLock'] ?? 0),
      );
      if (extraToLock == 0) {
        int newTotalClient = toInt(c.reneg?['newTotalClientPays'] ?? 0);
        if (newTotalClient > 0) extraToLock = newTotalClient - c.alreadyLocked;
      }
      int newTotalClient = toInt(
        c.reneg?['newTotalClientPays'] ?? c.alreadyLocked + extraToLock,
      );
      timeline.add(
        TimelineCard(
          title: 'Lock extra KES $extraToLock in escrow',
          body:
              'You accepted new price KES $newTotalClient. Already locked KES ${c.alreadyLocked}. Lock extra KES $extraToLock before fundi continues.',
          icon: Icons.lock_open,
          isDone: false,
          action: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => TimelineActions.payExtraEscrow(
              c.jobId,
              extraToLock,
              newTotalClient,
              c.renegStatus,
            ),
            child: Text('LOCK EXTRA KES $extraToLock NOW'),
          ),
        ),
      );
      return true;
    } else if (c.reneg != null &&
        toBool(c.reneg!['requested']) &&
        c.renegStatus == 'pending') {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Fundi requests price review - Waiting for you to review',
          message:
              '${c.reneg!['reasonDetails'] ?? 'Fundi sent new breakdown'}\nExtra labor: KES ${toInt(c.reneg!['extraLabor'])}\nWaiting for you to tap REVIEW BREAKDOWN.',
          action: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => Navigator.push(
                c.context,
                MaterialPageRoute(
                  builder: (_) =>
                      ClientPriceApprovalScreen(jobId: c.jobId, job: c.job),
                ),
              ),
              child: const Text('REVIEW BREAKDOWN'),
            ),
          ),
        ),
      );
      return true;
    }

    if (c.reneg != null &&
        (c.renegStatus.contains('accepted') ||
            c.renegStatus.contains('pending_extra_escrow') ||
            c.phase == 'waiting_for_client_to_buy_parts' ||
            c.phase == 'fundi_buying_parts')) {
      if (!toBool(c.reneg!['requested']) || c.renegStatus != 'pending') {
        timeline.add(
          TimelineCard(
            title: 'Price review - Reviewed - Done',
            body: 'You reviewed fundi breakdown - Done',
            icon: Icons.check_circle,
            isDone: true,
          ),
        );
      }
    }
    return false;
  }
}
