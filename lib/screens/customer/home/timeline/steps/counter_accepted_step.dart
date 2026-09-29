import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../timeline_actions.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class CounterAcceptedSteps {
  static bool handle(List<Widget> t, TimelineContext c) {
    final acceptedBy = (c.job['counterAcceptedBy'] as List?) ?? [];
    final isThisFundiAccepted =
        acceptedBy.contains(c.fundiId) ||
        c.job['lastCounterAcceptedBy'] == c.fundiId;
    final alreadyAssigned = c.job['assignedFundiId'] != null;

    if (!isThisFundiAccepted || alreadyAssigned) return false;

    final labour = c.labour; // 5000
    final transport = c.transport; // 100
    final fee = c.clientAppFee; // 250
    final total = c.totalToPay; // 5350

    t.add(
      TimelineCard(
        title: 'Fundi accepted your counter - KES $labour',
        body:
            '${c.fundiNameStr} accepted your counter KES $labour. Total to lock will be KES $total (labour $labour + transport $transport + fee $fee). Proceed only with the fundi you want.',
        icon: Icons.check_circle,
        isDone: false,
        action: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FundipapColors.greenSuccess,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: () =>
              TimelineActions.proceedWithFundi(c.jobId, c.fundiId, total),
          child: Text(
            'PROCEED WITH ${c.fundiNameStr.toUpperCase()} • PAY KES $total',
          ),
        ),
      ),
    );
    return true; // stop timeline here, don't show escrow yet
  }
}
