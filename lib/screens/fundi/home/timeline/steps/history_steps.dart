import 'package:flutter/material.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_context.dart';

void addHistoryCards(
  List<Widget> timeline,
  FundiTimelineContext c, {
  int bidAmount = 0,
  bool hasBid = false,
}) {
  timeline.add(
    fundiCard(
      color: Colors.green.shade50,
      border: Colors.green,
      icon: Icons.lock,
      iconColor: Colors.green,
      title: 'Escrow locked - Done KES ${c.fundiSeesWaiting}',
      message:
          'Labour KES ${c.labour} + Transport KES ${c.transport} = KES ${c.fundiSeesWaiting} locked. You will receive KES ${c.fundiReceives} after fee KES ${c.fundiAppFee}',
      time: 'Done',
      isDone: true,
    ),
  );
  if (c.extraPaid) {
    timeline.add(
      fundiCard(
        color: Colors.green.shade50,
        border: Colors.green,
        icon: Icons.lock_open,
        iconColor: Colors.green.shade800,
        title:
            'Client locked extra KES ${c.extraLabour} - Done (Total ${c.newTotalFundiLocked})',
        message:
            'Extra labour KES ${c.extraLabour} locked. New total KES ${c.newTotalFundiLocked}, you get KES ${c.newFundiReceivesVal}',
        time: 'Done',
        isDone: true,
      ),
    );
  }
  if (c.siteDone) {
    timeline.add(
      fundiCard(
        color: Colors.green.shade50,
        border: Colors.green,
        icon: Icons.location_on,
        iconColor: Colors.green,
        title: 'Site visited - Done',
        message: 'Done',
        time: 'Done',
        isDone: true,
      ),
    );
  }
  timeline.add(
    fundiCard(
      color: Colors.green.shade50,
      border: Colors.green,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      title: 'Bid accepted - Done',
      message:
          'Labour KES ${c.labour} + Transport KES ${c.transport} = KES ${c.fundiSeesWaiting} locked',
      time: 'Earlier',
      isDone: true,
    ),
  );

  if (hasBid) {
    int amount = bidAmount > 0 ? bidAmount : c.labour;
    timeline.add(
      fundiCard(
        color: Colors.green.shade50,
        border: Colors.green,
        icon: Icons.send,
        iconColor: Colors.green,
        title: 'Bid sent - Done KES $amount',
        message: 'You sent a bid for ${c.jobTitle} - KES $amount',
        time: 'Done',
        isDone: true,
      ),
    );
  }
}
