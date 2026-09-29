import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../timeline_actions.dart';
import '../timeline_utils.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class PartsSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    if (c.phase == 'waiting_for_client_to_buy_parts') {
      final oldLabor = toInt(
        c.reneg?['oldLabor'] ?? c.job['laborCost'] ?? c.job['agreedPrice'] ?? 0,
      );
      final transportVal = toInt(c.job['transportFee'] ?? 0);
      final oldClientFee = (oldLabor * 0.05).round();
      final alreadyLockedBase = oldLabor + transportVal + oldClientFee;
      final extraLaborVal = toInt(
        c.job['extraLaborAmount'] ?? c.reneg?['extraLabor'] ?? 0,
      );
      final extraAppVal = toInt(
        c.job['extraClientAppFee'] ??
            c.reneg?['extraApp'] ??
            (extraLaborVal * 0.05).round(),
      );
      final extraToLockVal = extraLaborVal + extraAppVal;
      final newTotalVal = alreadyLockedBase + extraToLockVal;
      final totalLockedNow = toInt(c.job['escrowAmount'] ?? newTotalVal);
      timeline.add(
        TimelineCard(
          title: 'You will buy parts - Confirm when bought',
          body:
              'Extra KES $extraToLockVal locked (Labour $extraLaborVal + App $extraAppVal). Total locked KES $totalLockedNow. Buy the listed parts then confirm.',
          icon: Icons.shopping_cart,
          isDone: false,
          action: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () => TimelineActions.confirmPartsBought(c.jobId),
            child: Text(
              'I HAVE BOUGHT PARTS - Notify Fundi',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ),
      );
    }
    if (c.phase == 'client_claims_parts_bought' ||
        c.phase == 'parts_confirmed_by_fundi' ||
        c.phase == 'fundi_working' ||
        c.status == 'in_progress' ||
        c.status.contains('completed')) {
      if (c.phase != 'waiting_for_client_to_buy_parts') {
        timeline.add(
          TimelineCard(
            title: 'You bought parts - Done',
            body: 'Parts purchase confirmed',
            icon: Icons.check_circle,
            isDone: true,
          ),
        );
      }
    }

    if (c.phase == 'client_claims_parts_bought') {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Parts bought - Waiting for fundi to confirm',
          message:
              'You marked parts as bought. Waiting for ${c.fundiName} to confirm.',
        ),
      );
      return true;
    } else if (c.phase == 'parts_confirmed_by_fundi' ||
        c.phase == 'fundi_working' ||
        c.status == 'in_progress' ||
        c.status.contains('completed')) {
      if (c.phase != 'waiting_for_client_to_buy_parts') {
        timeline.add(
          TimelineCard(
            title: 'Fundi confirmed parts - Done',
            body: 'Parts confirmed as available',
            icon: Icons.check_circle,
            isDone: true,
          ),
        );
      }
    }

    if (c.phase == 'parts_confirmed_by_fundi') {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Fundi confirmed parts - Waiting for fundi to start work',
          message:
              'Fundi confirmed your parts are available. Waiting for him to tap Start Job.',
        ),
      );
      return true;
    }
    return false;
  }
}
