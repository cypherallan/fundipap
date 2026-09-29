import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class WorkSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    if (c.status == 'site_visit' && c.phase.isEmpty) {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Waiting for fundi to start job',
          message:
              '${c.fundiName} arrived at ${c.location} and is on site. Waiting for him to Start Job.',
        ),
      );
      return true;
    } else if (c.status == 'in_progress' ||
        c.phase == 'fundi_working' ||
        c.status.contains('completed')) {
      timeline.add(
        TimelineCard(
          title: 'Waiting for fundi to start job - Done',
          body: 'Fundi started job',
          icon: Icons.check_circle,
          isDone: true,
        ),
      );
    }

    if (c.phase == 'fundi_working' || c.status == 'in_progress') {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Fundi is working - Waiting to complete',
          message:
              '${c.trade} in progress at ${c.location}. ${c.fundiName} is working. Waiting for him to tap MARK JOB AS COMPLETED.',
        ),
      );
      return true;
    }
    return false;
  }
}
