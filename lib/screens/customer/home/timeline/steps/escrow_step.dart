import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../timeline_actions.dart';
import '../widgets/timeline_card.dart';
import '../widgets/timeline_fee_breakdown.dart';
import '../timeline_context.dart';
import '../timeline_utils.dart';

class EscrowSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    final int oldLocked = c.reneg != null
        ? toInt(c.reneg?['oldLabor'] ?? 0)
        : 0;
       final int extraReq = c.reneg != null
        ? (() {
            int clientC = toInt(c.reneg?['clientCounterExtraLabor'] ?? 0);
            int fundiC = toInt(c.reneg?['fundiCounterExtraLabor'] ?? 0);
            if (c.renegStatus == 'countered_by_client') {
              return clientC > 0
                  ? clientC
                  : toInt(c.reneg?['counterExtraLabor'] ?? c.reneg?['extraLabor'] ?? 0);
            }
            if (c.renegStatus == 'countered_by_fundi') {
              return fundiC > 0
                  ? fundiC
                  : toInt(c.reneg?['extraLabor'] ?? 0);
            }
            int accepted = toInt(c.reneg?['acceptedCounterExtraLabor'] ?? 0);
            if (accepted > 0) return accepted;
            return toInt(
                c.reneg?['counterExtraLabor'] ?? c.reneg?['extraLabor'] ?? 0);
          })()
        : 0;
    final bool hasExtra = oldLocked > 0 && extraReq > 0;
    final int extraFee = hasExtra ? (extraReq * 0.05).round() : c.clientAppFee;
    final int extraToLockNow = hasExtra ? extraReq + extraFee : c.totalToPay;
    timeline.add(
      TimelineCard(
        title: 'Bid accepted - Done',
        body: '${c.trade} • ${c.location}',
        icon: Icons.verified,
        isDone: true,
        extra: FeeBreakdown(
          labour: c.labour,
          transport: c.transport,
          transportLabel: c.transportLabel,
          clientAppFee: hasExtra ? extraFee : c.clientAppFee,
          totalToPay: hasExtra ? extraToLockNow : c.totalToPay,
          oldLaborLocked: hasExtra ? oldLocked : null,
          extraRequested: hasExtra ? extraReq : null,
        ),
      ),
    );

    timeline.add(
      TimelineCard(
        title: c.escrowDone
            ? 'Escrow locked - KES ${c.alreadyLocked} secured'
            : 'Lock KES ${c.totalToPay} to escrow now',
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
                child: Text('Pay KES ${c.totalToPay} to Escrow'),
              )
            : null,
      ),
    );
    return !c.escrowDone;
  }
}
