import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../customer/confirm/client_price_approval_screen.dart';
import '../tracking/customer_tracking_screen.dart';

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
  Future<void> _payEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowPaidAt': FieldValue.serverTimestamp(),
      'escrowHeld': true,
    });
  }

  Future<void> _confirmCompletion(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fundipap',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var job = snap.data!.data() as Map<String, dynamic>;
          var escrow = (job['escrowStatus'] ?? 'pending').toString();
          var status = (job['status'] ?? '').toString();
          var location = (job['location'] ?? job['address'] ?? 'Your location')
              .toString();
          bool siteDone =
              (job['siteVisitDone'] == true) || (job['siteVisited'] == true);

          List<Widget> timeline = [];

          timeline.add(
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: FundipapColors.blackGray,
                    child: Text(
                      widget.fundiName.isNotEmpty
                          ? widget.fundiName[0].toUpperCase()
                          : 'F',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fundiName,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.trade,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          timeline.add(const Divider(height: 1));

          timeline.add(
            _timelineCard(
              title: 'Bid accepted - Done',
              body: '${widget.trade} • $location',
              icon: Icons.verified,
              isDone: true,
            ),
          );

          bool escrowDone = escrow == 'held' || escrow == 'paid';
          double agreed = (job['agreedPrice'] ?? job['budget'] ?? 0).toDouble();
          timeline.add(
            _timelineCard(
              title: escrowDone
                  ? 'Escrow locked - Done'
                  : 'Lock payment to escrow',
              body: escrowDone
                  ? 'KES ${agreed.toInt()} secured'
                  : 'Secure KES ${agreed.toInt()} to start',
              icon: Icons.lock,
              isDone: escrowDone,
              action: !escrowDone
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _payEscrow(widget.jobId, agreed),
                      child: Text('Pay KES ${agreed.toInt()} to Escrow'),
                    )
                  : null,
            ),
          );

          // SINGLE CARD FOR TRAVEL + ARRIVAL
          bool shouldShowTravel =
              (job['travelling'] == true) ||
              status == 'travelling' ||
              siteDone ||
              status == 'site_visit' ||
              status == 'in_progress' ||
              status == 'job_completed';
          if (shouldShowTravel) {
            timeline.add(
              _timelineCard(
                title: siteDone
                    ? 'Fundi arrived - Currently on site'
                    : 'Fundi is on the way',
                body: siteDone
                    ? 'At $location • Inspecting site now'
                    : 'Tap to track live location',
                icon: siteDone ? Icons.check_circle : Icons.location_on,
                isDone: siteDone, // turns green only when arrived
                onTap: siteDone
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerTrackingScreen(
                            jobId: widget.jobId,
                            job: job,
                          ),
                        ),
                      ),
              ),
            );
          }

          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          if (reneg != null &&
              reneg['requested'] == true &&
              reneg['status'] != 'accepted') {
            timeline.add(
              _timelineCard(
                title: 'Fundi requests price review',
                body: '${reneg['reasonDetails'] ?? ''}',
                icon: Icons.request_quote,
                isDone: false,
                action: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClientPriceApprovalScreen(
                        jobId: widget.jobId,
                        job: job,
                      ),
                    ),
                  ),
                  child: const Text('REVIEW BREAKDOWN'),
                ),
              ),
            );
          }

          if (status == 'in_progress') {
            timeline.add(
              _timelineCard(
                title: 'Fundi is working',
                body: '${widget.trade} in progress at $location',
                icon: Icons.construction,
                isDone: false,
              ),
            );
          }

          if (status == 'job_completed' ||
              status == 'pending_completion' ||
              status == 'completed') {
            bool isDone = status == 'completed';
            timeline.add(
              _timelineCard(
                title: isDone
                    ? 'Job Completed - Done'
                    : 'Job completed - Confirm',
                body: isDone
                    ? 'Payment released'
                    : 'Tap to confirm and release',
                icon: Icons.verified,
                isDone: isDone,
                action: !isDone
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.greenSuccess,
                        ),
                        onPressed: () => _confirmCompletion(widget.jobId),
                        child: const Text(
                          'Confirm Completion',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : null,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: timeline,
          );
        },
      ),
    );
  }

  Widget _timelineCard({
    required String title,
    required String body,
    required IconData icon,
    bool isDone = false,
    Widget? action,
    VoidCallback? onTap,
  }) {
    return Card(
      color: isDone ? Colors.green.shade50 : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDone ? Colors.green : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isDone)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                  if (isDone) const SizedBox(width: 6),
                  Icon(icon, size: 18, color: isDone ? Colors.green : null),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isDone ? Colors.green.shade800 : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(body, style: GoogleFonts.inter(fontSize: 11)),
              if (action != null) ...[const SizedBox(height: 10), action],
            ],
          ),
        ),
      ),
    );
  }
}
