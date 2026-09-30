import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../widgets/chat_sheet.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';

Widget buildBidSentView(
  BuildContext context,
  FundiTimelineContext c,
  int bidAmount,
) {
  int amount = bidAmount > 0 ? bidAmount : c.labour;
  return Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => FundiTimelineActions.goBackToMyJobs(context, tab: 2),
      ),
      title: Text(c.clientName),
      backgroundColor: FundipapColors.blackGray,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          onPressed: () => openChatSheet(context, c.jobId, c.clientName),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        OrangeAnimatedWaitingCard(
          title: 'Bid sent - KES $amount',
          message:
              'You sent a bid for ${c.jobTitle} - KES $amount waiting for client to respond.',
        ),
      ],
    ),
  );
}
