import 'package:flutter/material.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../widgets/timeline_card.dart';
import '../fundi_timeline_actions.dart';
import '../fundi_timeline_context.dart';

bool handleWorkSteps(List<Widget> timeline, FundiTimelineContext c) {
  if (c.renegStatus == 'pending' || c.renegStatus == 'countered_by_fundi') {
    timeline.add(
      OrangeAnimatedWaitingCard(
        title: 'Waiting for client to confirm price review',
        message:
            'You requested new labour charge KES ${c.extraLabour}. Waiting for ${c.clientName} to review.',
      ),
    );
    return false;
  }
  if (c.phase == 'completed_by_fundi' ||
      c.status == 'job_completed' ||
      c.status == 'pending_completion') {
    timeline.add(
      OrangeAnimatedWaitingCard(
        title: 'Job Completed - Waiting for ${c.clientName} to confirm',
        message:
            'You marked ${c.jobTitle} as completed. Waiting for ${c.clientName} to confirm and release payment.',
      ),
    );
    return false;
  }
  if (c.phase == 'parts_confirmed_by_fundi') {
    timeline.add(
      fundiCard(
        color: Colors.green.shade50,
        border: Colors.green,
        icon: Icons.check_circle,
        iconColor: Colors.green.shade800,
        title: 'Materials confirmed',
        message: 'Press START WORK',
        time: 'Now',
        isCurrent: true,
        action: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FundipapColors.blackGray,
            minimumSize: const Size(double.infinity, 52),
          ),
          onPressed: () => FundiTimelineActions.startJob(c.jobId),
          child: const Text(
            'START WORK',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
    return false;
  }
  if (c.status == 'in_progress' || c.phase == 'fundi_working') {
    timeline.add(
      fundiCard(
        color: Colors.orange.shade50,
        border: Colors.orange,
        icon: Icons.construction,
        iconColor: Colors.orange.shade800,
        title: 'You are working',
        message: 'You are working on ${c.jobTitle}.',
        time: 'Now',
        isCurrent: true,
        action: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: FundipapColors.greenSuccess,
            minimumSize: const Size(double.infinity, 52),
          ),
          onPressed: () => FundiTimelineActions.completeJob(c.jobId),
          child: const Text(
            'MARK JOB AS COMPLETED',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
    return false;
  }
  return false;
}
