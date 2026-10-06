import 'package:flutter/material.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../timeline_utils.dart';
import '../widgets/timeline_card.dart';
import '../timeline_context.dart';

bool _hasParts(Map<String, dynamic>? renego) {
  if (renego == null) return false;
  var list = renego['partsNeeded'] as List?;
  if (list != null && list.isNotEmpty) return true;
  int est = toInt(renego['partsEstimateTotal']);
  int total = toInt(renego['totalPartsEstimate']);
  String till = (renego['tillNumber'] ?? '').toString().trim();
  return est > 0 || total > 0 || till.isNotEmpty;
}

class WorkSteps {
  static bool handle(List<Widget> timeline, TimelineContext c) {
    bool hasParts = _hasParts(c.reneg);

    // FIX: Exact same logic as HomeStatusWidget that shows notification correctly
    bool isSiteVisitPhase =
        c.status == 'site_visit' ||
        c.phase == 'waiting_for_client_to_buy_parts' ||
        c.phase == 'fundi_buying_parts' ||
        c.phase == 'client_claims_parts_bought' ||
        c.phase == 'parts_confirmed_by_fundi' ||
        c.phase.contains('waiting_for_fundi_to_start');

    if (isSiteVisitPhase) {
      if (!hasParts) {
        timeline.add(
          const OrangeAnimatedWaitingCard(
            title: 'Waiting for fundi to start job',
            message:
                'Extra labour locked. Fundi will start working now - no parts needed.',
          ),
        );
        return true;
      }
    }

    if (c.status == 'site_visit' && !hasParts) {
      timeline.add(
        OrangeAnimatedWaitingCard(
          title: 'Waiting for fundi to start job',
          message:
              '${c.fundiName} arrived at ${c.location} and is on site. Waiting for him to Start Job.',
        ),
      );
      return true;
    }

    if (c.status == 'in_progress' ||
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
              '${c.trade} in progress at ${c.location}. ${c.fundiName} is working.',
        ),
      );
      return true;
    }
    return false;
  }
}
