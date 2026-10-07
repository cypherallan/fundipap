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

  bool _toBool(dynamic v, [bool fb = false]) {
    if (v == null) return fb;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return fb;
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
          if (!snap.hasData || !snap.data!.exists)
            return const Center(child: Text('Job not found'));
          var job = snap.data!.data() as Map<String, dynamic>;

          var status = (job['status'] ?? '').toString();
          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          String renegStatus = (reneg?['status'] ?? '').toString();
          bool isRenegCountered = renegStatus == 'countered_by_client';
          bool isRenegApprovedNeedsTopup =
              renegStatus == 'approved' &&
              (_toBool(job['clientNeedsToTopup']) ||
                  job['escrowStatus'] == 'pending_topup');

          String phase = (reneg?['currentPhase'] ?? '').toString();
          bool isStarted =
              status == 'in_progress' ||
              phase == 'fundi_working' ||
              status == 'job_completed' ||
              status == 'pending_completion' ||
              status == 'completed';
          bool isCancelled = status.toLowerCase().contains('cancel');
          bool canClientCancel = !isStarted && !isCancelled;

          // Extract fixed job location for banner
          var jobLoc =
              job['location'] ?? widget.jobData['location'] ?? 'Job site';
          var jobGeo =
              job['geopoint'] ?? job['location'] ?? widget.jobData['geopoint'];
          String jobLatLng = '';
          if (jobGeo is GeoPoint) {
            jobLatLng =
                '${jobGeo.latitude.toStringAsFixed(4)}, ${jobGeo.longitude.toStringAsFixed(4)}';
          }

          List<Widget> timeline = TimelineStepsBuilder.build(
            context: context,
            job: job,
            fundiName: widget.fundiName,
            trade: widget.trade,
            jobId: widget.jobId,
            releasing: _releasing,
            onReleasing: (v) => setState(() => _releasing = v),
          );

          // Fixed location banner - ALWAYS at top
          Widget locationBanner = Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300, width: 1.2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.push_pin, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job site (fixed when you posted)',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$jobLoc${jobLatLng.isNotEmpty ? ' • $jobLatLng' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fundi ${widget.fundiName} will come HERE, even if you move to a different location. This location does not follow you.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          // STATE 1: You countered 2000 -> 1000, waiting for fundi
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
                      ],
                    ),
                  ),
                ],
              ),
            );
            timeline = [locationBanner, waitingCounter, ...timeline];
          } else if (isRenegApprovedNeedsTopup) {
            int approvedExtra = _toInt(
              reneg?['approvedExtra'] ??
                  reneg?['counterExtraLabor'] ??
                  job['extraTopupAmount'] ??
                  1000,
            );
            int approvedToLock = _toInt(
              reneg?['approvedExtraToLock'] ??
                  reneg?['counterExtraToLock'] ??
                  job['extraTopupToLock'] ??
                  (approvedExtra * 1.05).round(),
            );
            Widget waitingTopup = Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_open,
                        color: Colors.blue.shade800,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fundi accepted your counter - Lock extra KES $approvedToLock',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You countered 2000 -> $approvedExtra. Fundi accepted. Please lock KES $approvedToLock (KES $approvedExtra + 5% fee) to continue.',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Locking extra KES $approvedToLock...',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'LOCK EXTRA KES $approvedToLock',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            timeline = [
              locationBanner,
              waitingTopup,
              ...timeline.where((w) => true),
            ];
          } else {
            timeline = [locationBanner, ...timeline];
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
