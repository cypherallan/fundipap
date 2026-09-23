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
  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  double _toDouble(dynamic v, [double fb = 0]) {
    if (v == null) return fb;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  Future<void> _payEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowPaidAt': FieldValue.serverTimestamp(),
      'escrowHeld': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _payExtraEscrow(
    String jobId,
    int extra,
    int newTotal,
    String currentRenegStatus,
  ) async {
    String finalStatus = currentRenegStatus.replaceAll(
      '_pending_extra_escrow',
      '',
    );
    bool clientBuys = finalStatus.contains('client_buys');
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': newTotal,
      'extraEscrowStatus': 'paid',
      'extraEscrowPaidAt': FieldValue.serverTimestamp(),
      'status': 'site_visit', // fundi left, must start work after parts
      'renegotiation.status': finalStatus,
      'renegotiation.requested': false,
      'renegotiation.currentPhase': clientBuys
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmPartsBought(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.currentPhase': 'client_claims_parts_bought',
      'renegotiation.clientPartsBought': true,
      'renegotiation.clientPartsBoughtAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmCompletion(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
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

          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          String renegStatus = (reneg?['status'] ?? '').toString();
          String phase = (reneg?['currentPhase'] ?? '').toString();
          bool needsExtraEscrow = renegStatus.contains('pending_extra_escrow');

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
          double agreed = _toDouble(job['agreedPrice'] ?? job['budget'] ?? 0);
          int alreadyLocked = _toInt(job['escrowAmount'] ?? agreed);

          timeline.add(
            _timelineCard(
              title: escrowDone
                  ? 'Escrow locked - Done'
                  : 'Lock payment to escrow',
              body: escrowDone
                  ? 'KES $alreadyLocked secured'
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
                isDone: siteDone,
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

          // EXTRA ESCROW REQUIRED
          if (needsExtraEscrow) {
            int extra = _toInt(
              job['extraLaborAmount'] ?? job['extraEscrowAmount'] ?? 0,
            );
            if (extra == 0) {
              int oldL = _toInt(reneg?['oldLabor'] ?? 0);
              int newL = _toInt(reneg?['newLaborTotal'] ?? 0);
              if (oldL > 0 && newL > 0) extra = newL - oldL;
            }
            int newTotal = _toInt(job['agreedPrice'] ?? alreadyLocked + extra);
            timeline.add(
              _timelineCard(
                title: 'Lock extra KES $extra in escrow',
                body:
                    'You accepted new price KES $newTotal. Already locked KES $alreadyLocked. Lock extra KES $extra before fundi continues.',
                icon: Icons.lock_open,
                isDone: false,
                action: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _payExtraEscrow(
                    widget.jobId,
                    extra,
                    newTotal,
                    renegStatus,
                  ),
                  child: Text('LOCK EXTRA KES $extra NOW'),
                ),
              ),
            );
          } else if (reneg != null &&
              reneg['requested'] == true &&
              renegStatus == 'pending') {
            timeline.add(
              _timelineCard(
                title: 'Fundi requests price review',
                body:
                    '${reneg['reasonDetails'] ?? ''}\nExtra labor: KES ${_toInt(reneg['extraLabor'])}',
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

          // CLIENT BOUGHT PARTS CONFIRMATION
          if (phase == 'waiting_for_client_to_buy_parts') {
            timeline.add(
              _timelineCard(
                title: 'You will buy parts - Confirm when bought',
                body:
                    'Extra KES ${_toInt(job['extraLaborAmount'])} locked. Buy the listed parts/materials then confirm below. Fundi will verify parts before starting work.',
                icon: Icons.shopping_cart,
                isDone: false,
                action: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _confirmPartsBought(widget.jobId),
                  child: Text(
                    'I HAVE BOUGHT PARTS - Notify Fundi',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            );
          } else if (phase == 'client_claims_parts_bought') {
            timeline.add(
              _timelineCard(
                title: 'Parts bought - Waiting for fundi to confirm',
                body:
                    'You marked parts as bought. Waiting for ${widget.fundiName} to confirm parts are correct & available.',
                icon: Icons.hourglass_top,
                isDone: false,
              ),
            );
          } else if (phase == 'parts_confirmed_by_fundi') {
            timeline.add(
              _timelineCard(
                title: 'Fundi confirmed parts - Starting work',
                body:
                    'Fundi confirmed your parts are available. He will start work now.',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
          } else if (phase == 'fundi_working' || status == 'in_progress') {
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
