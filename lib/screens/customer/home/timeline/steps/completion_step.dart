import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../timeline_actions.dart';
import '../timeline_utils.dart';
import '../widgets/timeline_card.dart';
import '../widgets/timeline_fee_breakdown.dart';
import '../timeline_context.dart';

class CompletionSteps {
  static void handle(List<Widget> timeline, TimelineContext c) {
    if (c.status == 'job_completed' || c.status == 'pending_completion') {
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
                    : toInt(
                        c.reneg?['counterExtraLabor'] ??
                            c.reneg?['extraLabor'] ??
                            0,
                      );
              }
              if (c.renegStatus == 'countered_by_fundi') {
                return fundiC > 0 ? fundiC : toInt(c.reneg?['extraLabor'] ?? 0);
              }
              int accepted = toInt(c.reneg?['acceptedCounterExtraLabor'] ?? 0);
              if (accepted > 0) return accepted;
              return toInt(
                c.reneg?['counterExtraLabor'] ?? c.reneg?['extraLabor'] ?? 0,
              );
            })()
          : 0;
      final bool hasExtra = oldLocked > 0 && extraReq > 0;
      int baseLabour = toInt(c.labour);
      int newLabour = hasExtra ? oldLocked + extraReq : baseLabour;
      int transportVal = toInt(c.job['transportFee'] ?? 0);
      int clientFee = (newLabour * 0.05).round();
      int totalToRelease = newLabour + transportVal + clientFee;

      timeline.add(
        TimelineCard(
          title:
              'Job Completed by ${c.fundiName} - Confirm & Release KES $totalToRelease',
          body:
              'Fundi marked job as complete. Confirm to release KES $totalToRelease (fundi gets labour+transport minus fee)',
          icon: Icons.verified,
          isDone: false,
          extra: ReleaseFeeBreakdown(
            labour: newLabour,
            transport: transportVal,
            clientFee: clientFee,
            total: totalToRelease,
            oldLaborLocked: hasExtra ? oldLocked : null,
            extraRequested: hasExtra ? extraReq : null,
          ),
          action: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FundipapColors.greenSuccess,
              ),
              onPressed: c.releasing
                  ? null
                  : () => TimelineActions.confirmCompletion(
                      jobId: c.jobId,
                      fundiId: c.fundiId,
                      fundiName: c.fundiName,
                      trade: c.trade,
                      context: c.context,
                      onReleasing: c.onReleasing,
                    ),
              child: c.releasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'CONFIRM & RELEASE KES $totalToRelease',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
            ),
          ),
        ),
      );
    }
    if (c.status == 'in_progress' ||
        c.phase == 'fundi_working' ||
        c.status == 'job_completed' ||
        c.status == 'pending_completion' ||
        c.status == 'completed') {
      timeline.add(
        Card(
          color: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.green.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Job started - Cancel inactive for both. Must complete the job.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
  }
}
