import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';

bool handlePartsSteps(List<Widget> timeline, FundiTimelineContext c) {
  if (c.phase == 'waiting_for_client_to_buy_parts' ||
      c.status == 'waiting_for_client_to_buy_parts') {
    timeline.add(
      OrangeAnimatedWaitingCard(
        title: 'Waiting for client to buy materials',
        message:
            'Client locked extra labour KES ${c.extraLabour} (counter ${c.counterExtra} accepted). Total locked KES ${c.newTotalFundiLocked}. Waiting for materials.',
      ),
    );
    return false;
  }
  if (c.phase == 'client_claims_parts_bought' ||
      c.status == 'client_claims_parts_bought') {
    timeline.add(
      fundiCard(
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
          onPressed: () => FundiTimelineActions.confirmPartsAvailable(c.jobId),
          child: const Text(
            'CONFIRM MATERIALS AVAILABLE',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
    return true;
  }
  return false;
}
