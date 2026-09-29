import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../../tracking/customer_tracking_screen.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

class TravellingSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    if (!c.isTravelling &&
        !c.siteDone &&
        c.status != 'site_visit' &&
        c.status != 'in_progress' &&
        !c.status.contains('completed') &&
        c.phase != 'fundi_working') {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Waiting for fundi to start travelling',
          message:
              'Escrow of KES ${c.alreadyLocked} secured. ${c.fundiName} has NOT started travelling yet.',
        ),
      );
    } else {
      timeline.add(
        TimelineCard(
          title: 'Fundi started travelling - Done',
          body: '${c.fundiName} tapped Start Site Visit',
          icon: Icons.check_circle,
          isDone: true,
        ),
      );
    }

    if (c.isTravelling && !c.siteDone) {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Fundi is on the way - Waiting to arrive',
          message:
              '${c.fundiName} is travelling to ${c.location}. Tracking live.',
          onTap: () => Navigator.push(
            c.context,
            MaterialPageRoute(
              builder: (_) =>
                  CustomerTrackingScreen(jobId: c.jobId, job: c.job),
            ),
          ),
          action: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.location_on, size: 16),
            label: const Text('TRACK LIVE LOCATION'),
            onPressed: () => Navigator.push(
              c.context,
              MaterialPageRoute(
                builder: (_) =>
                    CustomerTrackingScreen(jobId: c.jobId, job: c.job),
              ),
            ),
          ),
        ),
      );
    } else if (c.siteDone) {
      timeline.add(
        TimelineCard(
          title: 'Fundi was on the way - Done',
          body: 'Travelling completed',
          icon: Icons.check_circle,
          isDone: true,
        ),
      );
    }

    if (c.siteDone) {
      timeline.add(
        TimelineCard(
          title: 'Fundi arrived - Currently on site - Done',
          body: 'At ${c.location} • Inspecting site now - Done',
          icon: Icons.check_circle,
          isDone: true,
        ),
      );
    }

    return !c.siteDone;
  }
}
