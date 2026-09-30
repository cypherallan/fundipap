import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../../../my_jobs/fundi_request_new_price_screen.dart';
import '../../fundi_visit_customer_tab.dart'; // FIX: public VisitCustomerScreen

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return v is! String;
}

bool handleSiteVisitSteps(List<Widget> timeline, FundiTimelineContext c) {
  String escrowRaw = (c.job['escrowStatus'] ?? 'pending')
      .toString()
      .toLowerCase();
  bool escrowDone = ['held', 'paid', 'released'].contains(escrowRaw);
  bool siteDone =
      _toBool(c.job['siteVisitDone']) ||
      _toBool(c.job['siteVisited']) ||
      c.job['siteVisitedAt'] != null ||
      c.siteDone;
  bool travelling =
      !siteDone &&
      (c.travelling ||
          (c.job['travelling'] == true) ||
          c.status == 'travelling');

  if (!escrowDone) return false;

  var reneg = c.job['renegotiation'] as Map<String, dynamic>?;
  bool renegPending =
      reneg != null &&
      reneg['requested'] == true &&
      (reneg['status'] ?? 'pending') == 'pending';
  if (renegPending) return false;

  // 1. TRAVELLING - OPEN TRACKING
  if (travelling && !siteDone) {
    timeline.add(
      fundiCard(
        color: Colors.blue.shade50,
        border: Colors.blue,
        icon: Icons.directions_bike,
        iconColor: Colors.blue,
        title: 'You are on the way',
        message: 'Client sees you travelling',
        time: 'Now',
        isCurrent: true,
        action: ElevatedButton.icon(
          icon: const Icon(Icons.map),
          label: const Text('OPEN TRACKING / CONFIRM ARRIVAL'),
          onPressed: () => Navigator.push(
            c.context,
            MaterialPageRoute(
              builder: (_) => VisitCustomerScreen(jobId: c.jobId, job: c.job),
            ),
          ),
        ),
      ),
    );
    return true;
  }

  // 2. ESCROW LOCKED
  if (!siteDone && escrowDone) {
    timeline.add(
      fundiCard(
        color: Colors.white,
        border: FundipapColors.blackGray,
        icon: Icons.location_on,
        iconColor: Colors.black,
        title: 'Escrow locked - KES ${c.fundiSeesWaiting} secured',
        message:
            'Labour KES ${c.labour} + Transport KES ${c.transport} = KES ${c.fundiSeesWaiting} locked. Start site visit now.',
        time: 'Now',
        isCurrent: true,
        action: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
            icon: const Icon(Icons.navigation),
            label: const Text('START SITE VISIT'),
            onPressed: () => FundiTimelineActions.startSiteVisit(
              c.context,
              c.jobId,
              c.jobTitle,
            ),
          ),
        ),
      ),
    );
    return true;
  }

  // 3. SITE DONE -> START JOB
  if (siteDone) {
    bool isStarted = [
      'in_progress',
      'pending_completion',
      'job_completed',
    ].contains(c.status);
    if (isStarted) return false;

    timeline.add(
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FundipapColors.greenSuccess, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next action - Client locked KES ${c.fundiSeesWaiting} secured to escrow',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => FundiTimelineActions.startJob(c.jobId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.greenSuccess,
                    ),
                    child: const Text(
                      'START JOB',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      c.context,
                      MaterialPageRoute(
                        builder: (_) => FundiRequestNewPriceScreen(
                          jobId: c.jobId,
                          job: c.job,
                        ),
                      ),
                    ),
                    child: const Text('New Price'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return true;
  }

  return false;
}
