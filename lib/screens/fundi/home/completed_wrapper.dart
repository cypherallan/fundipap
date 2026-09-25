import 'package:flutter/material.dart';
import 'completed_jobs.dart';

class FundiCompletedWrapper extends StatelessWidget {
  const FundiCompletedWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.white, child: const FundiCompletedJobs());
  }
}
