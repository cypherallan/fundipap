import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app.dart';
import '../timeline/widgets/timeline_chat_sheet.dart';
import '../timeline/widgets/timeline_cancel_wrapper.dart';
import '../timeline/widgets/timeline_reversed_list.dart';
import '../../home/timeline/widgets/timeline_steps_builder.dart';

class CustomerFundiTimelinePage extends StatefulWidget {
  final String jobId;
  final String fundiName;
  final String trade;
  final Map<String, dynamic> jobData;
  const CustomerFundiTimelinePage({
    super.key,
    required this.jobId,
    required this.fundiName,
    required this.trade,
    required this.jobData,
  });
  @override
  State<CustomerFundiTimelinePage> createState() =>
      _CustomerFundiTimelinePageState();
}

class _CustomerFundiTimelinePageState extends State<CustomerFundiTimelinePage> {
  bool _releasing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => HomeNavigator(
                  role: 'client',
                  email: FirebaseAuth.instance.currentUser?.email ?? '',
                  initialIndex: 0,
                  initialJobStatusTab: 0,
                ),
              ),
              (r) => false,
            );
          },
        ),
        title: Text(
          'Fundipap',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () =>
                TimelineChatSheet.show(context, widget.jobId, widget.fundiName),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData || snap.data == null || !snap.data!.exists)
            return const Center(child: Text('Job not found'));
          final raw = snap.data!.data();
          if (raw == null) return const Center(child: Text('Job deleted'));
          var job = raw as Map<String, dynamic>;

          var status = (job['status'] ?? '').toString();
          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          String phase = (reneg?['currentPhase'] ?? '').toString();
          bool isStarted =
              status == 'in_progress' ||
              phase == 'fundi_working' ||
              status == 'job_completed' ||
              status == 'pending_completion' ||
              status == 'completed';
          bool isCancelled = status.toLowerCase().contains('cancel');
          bool canClientCancel = !isStarted && !isCancelled;

          List<Widget> timeline = TimelineStepsBuilder.build(
            context: context,
            job: job,
            fundiName: widget.fundiName,
            trade: widget.trade,
            jobId: widget.jobId,
            releasing: _releasing,
            onReleasing: (v) => setState(() => _releasing = v),
          );

          Widget list = ReversedTimelineList.buildList(timeline);
          return TimelineCancelWrapper(
            canCancel: canClientCancel,
            jobId: widget.jobId,
            job: job,
            child: list,
          );
        },
      ),
    );
  }
}
