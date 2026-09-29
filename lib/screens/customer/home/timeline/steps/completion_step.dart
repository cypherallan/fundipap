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
      int oldLabour = toInt(c.labour);
      int newLabour = toInt(
        c.reneg?['newLaborTotal'] ??
            oldLabour + toInt(c.reneg?['extraLabor'] ?? 0),
      );
      int transportVal = toInt(c.job['transportFee'] ?? 0);
      int newClientFee = (newLabour * 0.05).round();
      int newTotalClient = newLabour + transportVal + newClientFee;
      int totalToRelease = toInt(
        c.reneg?['newTotalClientPays'] ?? newTotalClient,
      );
      timeline.add(
        TimelineCard(
          title:
              'Job Completed by ${c.fundiName} - Confirm & Release KES $totalToRelease',
          body:
              'Fundi marked job as complete. Confirm to release KES $totalToRelease',
          icon: Icons.verified,
          isDone: false,
          extra: ReleaseFeeBreakdown(
            labour: newLabour,
            transport: transportVal,
            clientFee: newClientFee,
            total: totalToRelease,
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
                      'CONFIRM COMPLETION & RELEASE KES $totalToRelease',
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
            padding: const EdgeInsets.all(12),
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
