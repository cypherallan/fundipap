import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../widgets/timeline_card.dart';
import '../widgets/chat_sheet.dart';
import '../../../../customer/home/timeline/widgets/timeline_cancel_wrapper.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';

Widget buildEscrowWaitingView(
  BuildContext context,
  FundiTimelineContext c,
  List<Widget> timeline, {
  int bidAmount = 0,
  bool hasBid = false,
}) {
  timeline.insert(
    0,
    OrangeAnimatedWaitingCard(
      title: 'Waiting for client to pay KES ${c.fundiSeesWaiting} to escrow',
      message:
          'Client ${c.clientName} has confirmed you but has NOT locked money yet. You cannot start site visit until escrow is held.\n\nLabour KES ${c.labour} + Transport KES ${c.transport} = KES ${c.fundiSeesWaiting}',
    ),
  );
  timeline.insert(
    1,
    fundiCard(
      color: Colors.green.shade50,
      border: Colors.green,
      icon: Icons.check_circle,
      iconColor: Colors.green,
      title: 'Bid accepted - Done',
      message: 'Done',
      time: 'Earlier',
      isDone: true,
    ),
  );

  if (hasBid) {
    int amount = bidAmount > 0 ? bidAmount : c.labour;
    timeline.insert(
      2,
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

  Widget list = ListView.separated(
    padding: const EdgeInsets.all(12),
    itemCount: timeline.length,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, i) => timeline[i],
  );

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
    body: TimelineCancelWrapper(
      canCancel: c.canFundiCancel,
      jobId: c.jobId,
      job: c.job,
      isClient: false,
      child: list,
    ),
  );
}
