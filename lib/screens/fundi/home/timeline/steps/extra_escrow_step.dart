import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../fundi_timeline_context.dart';

bool handleExtraEscrowStep(List<Widget> timeline, FundiTimelineContext c) {
  if (c.renegStatus.contains('pending_extra_escrow')) {
    timeline.add(
      OrangeAnimatedWaitingCard(
        title: c.isCounterAccepted
            ? 'You accepted counter KES ${c.extraLabour} - Waiting for client to lock extra KES ${c.extraLabour}'
            : 'Waiting for client to lock extra KES ${c.extraLabour}',
        message: c.isCounterAccepted
            ? 'You accepted client counter of KES ${c.extraLabour}. New total KES ${c.newTotalFundiLocked} = Labour ${c.newLabour} + Transport ${c.transport}. Waiting for client to lock.'
            : 'You requested extra labour KES ${c.extraLabour}. New total KES ${c.newTotalFundiLocked} = Labour ${c.newLabour} + Transport ${c.transport}.',
      ),
    );
    return true;
  }
  return false;
}
