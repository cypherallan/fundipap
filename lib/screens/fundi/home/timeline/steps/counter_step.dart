import 'package:flutter/material.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../fundi_timeline_utils.dart';
import '../../../my_jobs/fundi_request_new_price_screen.dart';

bool handleCounterStep(List<Widget> timeline, FundiTimelineContext c) {
  if (c.renegStatus == 'countered_by_client') {
    int originalExtra = c.rawExtra;
    int counterExtraClient = toInt(c.reneg?['counterExtraLabor'] ?? 0);
    timeline.add(
      fundiCard(
        color: Colors.orange.shade50,
        border: Colors.orange,
        icon: Icons.compare_arrows,
        iconColor: Colors.orange.shade800,
        title:
            'Client countered extra KES $originalExtra with KES $counterExtraClient',
        message:
            'You requested KES $originalExtra. Client countered with KES $counterExtraClient. Accept to proceed with KES $counterExtraClient.',
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
                child: const Text('COUNTER AGAIN'),
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
