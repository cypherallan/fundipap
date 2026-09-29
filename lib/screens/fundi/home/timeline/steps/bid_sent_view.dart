import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_context.dart';
import '../fundi_timeline_actions.dart';

Widget buildBidSentView(
  BuildContext context,
  FundiTimelineContext c, {
  int bidAmount = 0,
}) {
  int amount = bidAmount > 0 ? bidAmount : c.labour;
  if (amount <= 0) amount = 1000;
  int rec = amount - (amount * 0.05).round() + c.transport;

  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 1),
      ),
      title: Text(c.jobTitle),
      backgroundColor: FundipapColors.blackGray,
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        OrangeAnimatedWaitingCard(
          title: 'Bid sent - KES $amount',
          message:
              'You sent a bid for job ${c.jobTitle} waiting for client to respond.\n\nYou will receive KES $rec if accepted.',
        ),
        const SizedBox(height: 10),
        fundiCard(
          color: Colors.green.shade50,
          border: Colors.green,
          icon: Icons.check_circle,
          iconColor: Colors.green,
          title: 'Bid submitted - Done',
          message: 'Waiting for client decision',
          time: 'Now',
          isDone: true,
        ),
      ],
    ),
  );
}
