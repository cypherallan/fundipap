import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../timeline_actions.dart';
import '../widgets/timeline_card.dart';
import '../widgets/timeline_fee_breakdown.dart';
import '../timeline_context.dart';

class EscrowSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    timeline.add(
      TimelineCard(
        title: 'Bid accepted - Done',
        body: '${c.trade} • ${c.location}',
        icon: Icons.verified,
        isDone: true,
        extra: FeeBreakdown(
          labour: c.labour, // 5000
          transport: c.transport, // 100 - FIXED
          transportLabel: c.transportLabel,
          clientAppFee: c.clientAppFee, // 250
          totalToPay: c.totalToPay, // 5350 - FIXED
        ),
      ),
    );

    timeline.add(
      TimelineCard(
        title: c.escrowDone
            ? 'Escrow locked - KES ${c.alreadyLocked} secured'
            : 'Lock KES ${c.totalToPay} to escrow now', // now 5350
        body: c.escrowDone
            ? 'KES ${c.alreadyLocked} is secured. It will be released to ${c.fundiNameStr} after you confirm the job is completed.'
            : 'This amount will be held in FundiApp and only released to Fundi ${c.fundiNameStr} after you confirm the job is completed.',
        icon: Icons.lock,
        isDone: c.escrowDone,
        action: !c.escrowDone
            ? ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => TimelineActions.payEscrow(c.jobId, c.agreed),
                child: Text(
                  'Pay KES ${c.totalToPay} to Escrow',
                ), // now Pay KES 5350
              )
            : null,
      ),
    );
    return !c.escrowDone;
  }
}
