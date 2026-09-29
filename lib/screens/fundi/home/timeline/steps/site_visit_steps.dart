import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';
import '../../../my_jobs/fundi_request_new_price_screen.dart';

bool handleSiteVisitSteps(List<Widget> timeline, FundiTimelineContext c) {
  if (!c.siteDone && c.travelling) {
    timeline.add(
      fundiCard(
        color: Colors.blue.shade50,
        border: Colors.blue,
        icon: Icons.directions_bike,
        iconColor: Colors.blue,
        title: 'You are on the way',
        message: 'Travelling to client',
        time: 'Now',
        isCurrent: true,
        action: ElevatedButton.icon(
          icon: const Icon(Icons.navigation),
          label: const Text('OPEN MAP'),
          onPressed: () => FundiTimelineActions.startSiteVisit(
            c.context,
            c.jobId,
            c.jobTitle,
          ),
        ),
      ),
    );
    return false;
  }
  if (!c.siteDone) {
    timeline.add(
      fundiCard(
        color: Colors.white,
        border: FundipapColors.blackGray,
        icon: Icons.location_on,
        iconColor: Colors.black,
        title: 'Escrow locked - Done KES ${c.fundiSeesWaiting}',
        message:
            'Labour KES ${c.labour} + Transport KES ${c.transport} = KES ${c.fundiSeesWaiting} locked.',
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
    return false;
  }
  if (c.siteDone &&
      (c.status == 'site_visit' ||
          c.status == 'assigned' ||
          c.status == 'confirmed')) {
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
    return false;
  }
  return false;
}
