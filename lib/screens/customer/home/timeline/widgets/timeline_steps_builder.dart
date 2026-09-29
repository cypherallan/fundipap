import 'package:flutter/material.dart';
import '../widgets/timeline_header.dart';
import '../timeline_context.dart';
import '../steps/completed_step.dart';
import '../steps/cancelled_step.dart';
import '../steps/escrow_step.dart';
import '../steps/travelling_step.dart';
import '../steps/renegotiation_step.dart';
import '../steps/parts_step.dart';
import '../steps/work_step.dart';
import '../steps/completion_step.dart';

class TimelineStepsBuilder {
  static List<Widget> build({
    required BuildContext context,
    required Map<String, dynamic> job,
    required String fundiName,
    required String trade,
    required String jobId,
    required bool releasing,
    required Function(bool) onReleasing,
  }) {
    final c = TimelineContext.fromJob(
      job: job,
      fundiName: fundiName,
      trade: trade,
      jobId: jobId,
      context: context,
      releasing: releasing,
      onReleasing: onReleasing,
    );
    List<Widget> timeline = [];
    timeline.add(TimelineHeader(fundiName: fundiName, trade: trade));
    timeline.add(const Divider(height: 1));

    if (CompletedSteps.handle(timeline, c)) return timeline;
    if (CancelledSteps.handle(timeline, c)) return timeline;
    if (EscrowSteps.handle(timeline, c)) return timeline;
    if (TravellingSteps.handle(timeline, c)) return timeline;
    if (RenegotiationSteps.handle(timeline, c)) return timeline;
    if (PartsSteps.handle(timeline, c)) return timeline;
    if (WorkSteps.handle(timeline, c)) return timeline;
    CompletionSteps.handle(timeline, c);

    return timeline;
  }
}
