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

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

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

          // FIX: detect extra counter
          String renegStatus = (reneg?['status'] ?? '').toString();
          bool isRenegCountered =
              renegStatus == 'countered_by_client' ||
              status == 'renegotiation_countered_by_client';

          List<Widget> timeline = TimelineStepsBuilder.build(
            context: context,
            job: job,
            fundiName: widget.fundiName,
            trade: widget.trade,
            jobId: widget.jobId,
            releasing: _releasing,
            onReleasing: (v) => setState(() => _releasing = v),
          );

          // FIX: inject waiting-for-fundi-to-confirm-extra at TOP instead of waiting-for-start
          if (isRenegCountered) {
            int extraLabor = _toInt(reneg?['counterExtraLabor']);
            int extraToLock = _toInt(
              reneg?['counterExtraToLock'] ??
                  extraLabor + (extraLabor * 0.05).round(),
            );
            Widget waitingCounter = Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade400, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top,
                    color: Colors.orange.shade800,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Waiting for fundi to confirm extra labour counter',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You countered extra KES $extraLabor (KES $extraToLock with 5% fee) • Waiting for ${widget.fundiName} to accept',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            'Extra to lock: KES $extraToLock (not 1150)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            // put waitingCounter at top, keep rest of timeline below
            timeline = [waitingCounter, ...timeline];
          }

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
