import 'package:flutter/material.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class CancelledSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    if (!c.status.toLowerCase().contains('cancel')) return false;
    String title;
    String body;
    final by = c.job['cancelledBy'] ?? '';
    final refund = c.job['clientRefund'] ?? 0;
    final fee = c.job['platformFee'] ?? 0;
    final payout = c.job['fundiPayout'] ?? 0;
    switch (c.status) {
      case 'cancelled_before_payment':
        title = 'Job cancelled';
        body = 'Cancelled by $by. No charge - payment was not made.';
        break;
      case 'auto_cancelled_no_arrival':
        title = 'Auto-cancelled - Fundi did not arrive';
        body =
            'Fundi did not arrive in time. Full refund KES $refund to client.';
        break;
      case 'cancelled_after_arrival':
        title = 'Job cancelled after arrival';
        body =
            'Cancelled by $by - Refund KES $refund - Fee KES $fee - Fundi gets KES $payout';
        break;
      default:
        title = 'Job cancelled';
        body =
            'Cancelled by $by - Refund KES $refund - Fee KES $fee - Fundi gets KES $payout';
    }
    timeline.add(
      TimelineCard(title: title, body: body, icon: Icons.cancel, isDone: false),
    );
    return true;
  }
}
