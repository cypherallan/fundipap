import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../../confirm/approval/client_price_approval_screen.dart';
import '../timeline_actions.dart';
import '../timeline_utils.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class RenegotiationSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    if (c.reneg != null &&
        (c.renegStatus == 'countered_by_fundi' ||
            (c.job['status'] ?? '').toString() ==
                'renegotiation_countered_by_fundi')) {
      int clientPrev = toInt(c.reneg!['clientCounterExtraLabor'] ?? 0);
      int fundiNew = toInt(
        c.reneg!['fundiCounterExtraLabor'] ?? c.reneg!['extraLabor'] ?? 0,
      );
      int fundiToLock = toInt(
        c.reneg!['fundiCounterExtraToLock'] ??
            c.reneg!['extraToLock'] ??
            fundiNew + (fundiNew * 0.05).round(),
      );
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Waiting for you to confirm extra labour',
          message:
              'Fundi countered your extra KES $clientPrev with KES $fundiNew (KES $fundiToLock to lock) Accept or counter back.',
        ),
      );
      return true;
    }

    if (c.reneg != null &&
        ((c.renegStatus == 'countered_by_client') ||
            (c.job['status'] ?? '').toString() ==
                'renegotiation_countered_by_client')) {
      int extraLabor = toInt(
        c.reneg!['clientCounterExtraLabor'] ??
            c.reneg!['counterExtraLabor'] ??
            0,
      );
      int extraToLock = toInt(
        c.reneg!['clientCounterExtraToLock'] ??
            c.reneg!['counterExtraToLock'] ??
            extraLabor + (extraLabor * 0.05).round(),
      );
      int extraRequested = toInt(
        c.reneg!['counteredExtraRequested'] ?? c.reneg!['extraLabor'] ?? 0,
      );

      timeline.add(
        OrangeAnimatedWaitingCard(
          title:
              'You countered extra KES $extraLabor - waiting for fundi to confirm',
          message:
              'You countered KES $extraRequested with KES $extraLabor (KES $extraToLock to lock). Waiting for fundi to accept or counter.',
        ),
      );
      return true;
    }

    if (c.needsExtraEscrow) {
      int rawExtraLabor = toInt(
        c.reneg?['extraLabor'] ?? c.job['extraLaborAmount'] ?? 0,
      );
      int counterExtraLabor = toInt(
        c.reneg?['acceptedCounterExtraLabor'] ??
            c.reneg?['counterExtraLabor'] ??
            0,
      );
      int extraLaborToShow = counterExtraLabor > 0
          ? counterExtraLabor
          : rawExtraLabor;

      int extraToLock = toInt(
        c.reneg?['acceptedCounterExtraToLock'] ??
            c.reneg?['counterExtraToLock'] ??
            c.reneg?['extraToLock'] ??
            c.job['extraToLock'] ??
            0,
      );
      if (extraToLock == 0) {
        extraToLock = extraLaborToShow + (extraLaborToShow * 0.05).round();
      }

      int newTotalClient = c.alreadyLocked + extraToLock;

      bool isCounterAccepted = counterExtraLabor > 0;
      String whoBuys = (c.reneg?['whoBuysParts'] ?? 'client').toString();

      timeline.add(
        TimelineCard(
          title: isCounterAccepted
              ? 'Fundi accepted your counter KES $extraLaborToShow - Lock extra KES $extraToLock'
              : 'Lock extra KES $extraToLock in escrow',
          body: isCounterAccepted
              ? 'Fundi accepted your counter KES $extraLaborToShow (was KES $rawExtraLabor). Already locked KES ${c.alreadyLocked}. Lock extra KES $extraToLock before fundi continues. Total KES $newTotalClient.'
              : 'You accepted new price KES $newTotalClient. Already locked KES ${c.alreadyLocked}. Lock extra KES $extraToLock before fundi continues.',
          icon: Icons.lock_open,
          isDone: false,
          action: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => TimelineActions.payExtraEscrow(
              c.jobId,
              extraLaborToShow,
              extraToLock,
              whoBuys,
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

    if (c.renegStatus == 'rejected_continued_old_price') {
      final code = (c.reneg!['rejectionCode'] ?? '').toString();
      final label = (c.reneg!['rejectionLabel'] ?? code).toString();
      timeline.add(
        TimelineCard(
          title: 'Extra rejected - Continuing old price',
          body:
              'You rejected extra: $label ($code). Fundi will do ONLY what was in your original photos at old price KES ${c.alreadyLocked}.',
          icon: Icons.block,
          isDone: true,
        ),
      );
      return true;
    }
    return false;
  }
}
