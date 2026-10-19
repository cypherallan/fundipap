import 'package:flutter/material.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../fundi_timeline_utils.dart';
import '../../../my_jobs/fundi_request_new_price_screen.dart';

bool handleCounterStep(List<Widget> timeline, FundiTimelineContext c) {
  // DEADLOCK after 3 low counters - fundi choice: continue old price OR withdraw with diagnostic fee
  // Generic, no hardcoding - works for all 140 jobs
  if (c.renegStatus.contains('deadlock')) {
    int oldLab = toInt(c.reneg?['oldLabor'] ?? c.labour);
    int transport = c.transport;
    int counterRound = toInt(c.reneg?['counterRound'] ?? 3);
    bool hasEvidence = false;
    try {
      var ev = (c.reneg?['evidencePhotoUrls'] ?? []) as List;
      var ver = (c.reneg?['verificationPhotoUrls'] ?? []) as List;
      hasEvidence =
          ev.isNotEmpty ||
          ver.isNotEmpty ||
          (c.reneg?['hasEvidence'] ?? false) == true;
    } catch (_) {}

    int diagnosticFee = hasEvidence
        ? (oldLab * 0.15).round().clamp(800, 1500)
        : 0;
    int totalCompensation = transport + diagnosticFee;

    timeline.add(
      fundiCard(
        color: Colors.red.shade50,
        border: Colors.red,
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red.shade800,
        title: 'Deadlock after $counterRound low counters - Your choice now',
        message: hasEvidence
            ? 'Client countered 0 or <30% ($counterRound times) despite your verified site photos (Set 1 verification + Set 2 evidence). System confirms genuine scope change.\n\nYou can:\n1. Continue with old price KES $oldLab (labour + transport KES $transport)\n2. Withdraw - you get transport KES $transport + diagnostic fee KES $diagnosticFee = KES $totalCompensation from client locked amount. Client loses fee as punishment.'
            : 'Client countered low $counterRound times. No verified photos yet (photos optional for now). You can continue old price or withdraw with only transport KES $transport (no diagnostic fee without verification).',
        time: 'Now',
        isCurrent: true,
        action: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: () => FundiTimelineActions.continueOldPrice(
                  c.jobId,
                  c.reneg,
                  oldLab,
                  transport,
                ),
                child: Text('CONTINUE WITH OLD KES $oldLab'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: () => FundiTimelineActions.withdrawWithCompensation(
                  c.jobId,
                  c.reneg,
                  oldLab,
                  transport,
                  hasEvidence,
                ),
                child: Text(
                  hasEvidence
                      ? 'WITHDRAW - GET KES $totalCompensation (transport + diagnostic)'
                      : 'WITHDRAW - GET KES $transport (transport only)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return true;
  }

  if (c.renegStatus == 'countered_by_client') {
    int originalExtra = c.rawExtra;
    int counterExtraClient = toInt(c.reneg?['counterExtraLabor'] ?? 0);
    int counterRound = toInt(c.reneg?['counterRound'] ?? 1);
    bool isLow = false;
    try {
      isLow =
          (c.reneg?['isLowCounter'] ?? false) == true ||
          counterExtraClient == 0;
    } catch (_) {
      isLow = counterExtraClient == 0;
    }

    timeline.add(
      fundiCard(
        color: isLow ? Colors.red.shade50 : Colors.orange.shade50,
        border: isLow ? Colors.red : Colors.orange,
        icon: Icons.compare_arrows,
        iconColor: isLow ? Colors.red.shade800 : Colors.orange.shade800,
        title: isLow
            ? 'Client countered 0 / low KES $counterExtraClient (Round $counterRound/3) - Counter again with better evidence'
            : 'Client countered extra KES $originalExtra with KES $counterExtraClient (Round $counterRound/3)',
        message: isLow
            ? 'Client says old price covers it. You requested KES $originalExtra, client countered KES $counterExtraClient.\n\nTip: Add verification photos (re-capture client fixed anchor) + evidence photos (why extra needed) to prove genuine. After 3 low counters you can withdraw with compensation.'
            : 'You requested KES $originalExtra. Client countered with KES $counterExtraClient. Accept to proceed with KES $counterExtraClient or counter again.',
        time: 'Now',
        isCurrent: true,
        action: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () => FundiTimelineActions.acceptCounter(
                  c.jobId,
                  c.reneg,
                  c.labour,
                  c.transport,
                ),
                child: Text('ACCEPT KES $counterExtraClient'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  c.context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FundiRequestNewPriceScreen(jobId: c.jobId, job: c.job),
                  ),
                ),
                child: const Text('COUNTER AGAIN WITH BETTER EVIDENCE'),
              ),
            ),
          ],
        ),
      ),
    );
    return true;
  }
  return false;
}
