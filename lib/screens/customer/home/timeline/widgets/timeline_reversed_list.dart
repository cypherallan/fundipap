import 'package:flutter/material.dart';

class ReversedTimelineList extends StatelessWidget {
  final List<Widget> timeline;

  const ReversedTimelineList({super.key, required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.length <= 2) {
      return ListView(padding: const EdgeInsets.all(12), children: timeline);
    }
    final header = timeline[0];
    final divider = timeline[1];
    final notifications = timeline.sublist(2).reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [header, divider, ...notifications],
    );
  }

  static Widget buildList(List<Widget> timeline) {
    if (timeline.length <= 2)
      return ListView(padding: const EdgeInsets.all(12), children: timeline);
    final header = timeline[0];
    final divider = timeline[1];
    final notifications = timeline.sublist(2).reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [header, divider, ...notifications],
    );
  }
}
