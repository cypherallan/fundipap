import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../customer/confirm/client_price_approval_screen.dart';
import '../tracking/customer_tracking_screen.dart';
import '../../../widgets/animated_waiting_card.dart';
import '../rating/rate_fundi_screen.dart'; // <-- NEW

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
      'status': 'site_visit',
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

  Future<void> _confirmCompletion(String jobId, String fundiId) async {
    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var snap = await jobRef.get();
    var j = snap.data() as Map<String, dynamic>;
    var reneg = j['renegotiation'] as Map<String, dynamic>?;
    int initialAmount =
        (j['escrowAmount'] ?? j['agreedPrice'] ?? j['budgetMax'] ?? 0).toInt();
    int extraAmount =
        (j['extraLaborAmount'] ??
                reneg?['extraLabor'] ??
                reneg?['pendingLabor'] ??
                0)
            .toInt();
    int newLaborTotal = (reneg?['newLaborTotal'] ?? 0).toInt();
    int totalRelease = newLaborTotal > 0
        ? newLaborTotal
        : initialAmount + extraAmount;
    if (totalRelease == 0) totalRelease = initialAmount;

    await jobRef.update({
      'status': 'completed',
      'escrowStatus': 'released',
      'extraEscrowStatus': 'released',
      'clientConfirmedComplete': true,
      'completedAt': FieldValue.serverTimestamp(),
      'totalReleasedAmount': totalRelease,
      'fundiPayoutAmount': totalRelease,
      'initialEscrowReleased': initialAmount,
      'extraEscrowReleased': extraAmount,
      'fundiHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    try {
      await FirebaseFirestore.instance
          .collection('escrowTransactions')
          .doc(jobId)
          .update({
            'status': 'released',
            'amount': totalRelease,
            'initialAmount': initialAmount,
            'extraAmount': extraAmount,
            'releasedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RateFundiScreen(
          jobId: jobId,
          fundiId: fundiId,
          fundiName: widget.fundiName,
          trade: widget.trade,
        ),
      ),
    );
  }

  Widget _buildReversedList(List<Widget> timeline) {
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
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData || snap.data == null || !snap.data!.exists) {
            return const Center(child: Text('Job not found'));
          }
          final raw = snap.data!.data();
          if (raw == null) {
            return const Center(child: Text('Job deleted'));
          }
          var job = raw as Map<String, dynamic>;
          var escrow = (job['escrowStatus'] ?? 'pending').toString();
          var status = (job['status'] ?? '').toString();
          var location = (job['location'] ?? job['address'] ?? 'Your location')
              .toString();
          bool siteDone =
              (job['siteVisitDone'] == true) || (job['siteVisited'] == true);
          bool isTravelling =
              (job['travelling'] == true) &&
              job['siteVisitStarted'] == true &&
              !siteDone;
          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          String renegStatus = (reneg?['status'] ?? '').toString();
          String phase = (reneg?['currentPhase'] ?? '').toString();
          bool needsExtraEscrow = renegStatus.contains('pending_extra_escrow');
          // inside build, replace the agreed/alreadyLocked block with this:
          double agreed = _toDouble(
            job['totalCost'] ??
                job['escrowAmount'] ??
                job['agreedPrice'] ??
                job['acceptedBidAmount'] ??
                job['fundiBidAmount'] ??
                job['initialAgreedPrice'] ??
                job['budgetMax'] ??
                job['budget'] ??
                0,
          );
          int labor = _toInt(job['laborCost'] ?? job['agreedPrice'] ?? agreed);
          int transport = _toInt(
            job['transportFee'] ?? job['escrowTransport'] ?? 0,
          );
          double km = _toDouble(job['transportDistanceKm'] ?? 0);
          String mode = (job['transportMode'] ?? 'boda').toString();
          int alreadyLocked = _toInt(
            job['escrowAmount'] ?? 0,
          ); // DON'T fallback to agreed
          bool escrowHeldFlag =
              job['escrowHeld'] == true || job['escrowPaidAt'] != null;
          bool escrowDone =
              ['held', 'paid', 'released'].contains(escrow) ||
              escrowHeldFlag ||
              alreadyLocked > 0 ||
              status == 'escrow_locked' ||
              status == 'completed';
          bool clientRated = job['clientRated'] == true;
          String fundiId = (job['fundiId'] ?? job['assignedFundiId'] ?? '')
              .toString();

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

          // IF COMPLETED AND NOT RATED -> ONLY SHOW COMPLETED + MANDATORY RATE (clears other notifications for this fundi)
          if (status == 'completed' && !clientRated) {
            timeline.add(
              _timelineCard(
                title: 'Job completed by ${widget.fundiName} - Done',
                body:
                    'Payment KES ${job['totalReleasedAmount'] ?? alreadyLocked} released. Please rate ${widget.fundiName} to clear this job.',
                icon: Icons.verified,
                isDone: true,
              ),
            );
            timeline.add(
              Card(
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.orange.shade700, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.star_rate_rounded,
                        size: 48,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rate ${widget.fundiName} - Mandatory',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This notification will be cleared only after you rate and review. This is mandatory to complete the job.',
                        style: GoogleFonts.inter(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RateFundiScreen(
                                jobId: widget.jobId,
                                fundiId: fundiId,
                                fundiName: widget.fundiName,
                                trade: widget.trade,
                              ),
                            ),
                          ),
                          child: Text(
                            'RATE ${widget.fundiName.toUpperCase()} NOW',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return _buildReversedList(timeline);
          }

          if (status == 'completed' && clientRated) {
            timeline.add(
              _timelineCard(
                title: 'Job completed by ${widget.fundiName} - Rated - Done',
                body:
                    'You rated ${job['clientRating'] ?? 5} stars - KES ${job['totalReleasedAmount'] ?? alreadyLocked} released. Notifications for this fundi cleared.',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
            return _buildReversedList(timeline);
          }

          // Normal flow below
          // Normal flow below
          timeline.add(
            _timelineCard(
              title: 'Bid accepted - Done',
              body: transport > 0
                  ? '${widget.trade} • $location • Labor KES $labor + Transport KES $transport ($mode ${km.toStringAsFixed(1)}km) = KES ${agreed.toInt()} mutual'
                  : '${widget.trade} • $location • KES ${agreed.toInt()} mutual',
              icon: Icons.verified,
              isDone: true,
            ),
          );
          timeline.add(
            _timelineCard(
              title: escrowDone
                  ? 'Escrow locked - Done (Mutual Price)'
                  : 'Lock mutual price to escrow',
              body: escrowDone
                  ? 'KES $alreadyLocked secured${transport > 0 ? ' (Labor $labor + Transport $transport)' : ''}'
                  : transport > 0
                  ? 'You accepted fundi bid KES $labor + Transport KES $transport = Total KES ${agreed.toInt()}. Secure it to start.'
                  : 'You accepted fundi bid KES ${agreed.toInt()}. Secure it to start.',
              icon: Icons.lock,
              isDone: escrowDone,
              action: !escrowDone
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _payEscrow(widget.jobId, agreed),
                      child: Text(
                        'Pay KES ${agreed.toInt()} to Escrow (Mutual)',
                      ),
                    )
                  : null,
            ),
          );
          if (!escrowDone) {
            return _buildReversedList(timeline);
          }

          if (!isTravelling &&
              !siteDone &&
              status != 'site_visit' &&
              status != 'in_progress' &&
              !status.contains('completed') &&
              phase != 'fundi_working') {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title: 'Waiting for fundi to start travelling',
                message:
                    'Escrow of KES $alreadyLocked secured. ${widget.fundiName} has NOT started travelling yet.',
              ),
            );
          } else {
            timeline.add(
              _timelineCard(
                title: 'Fundi started travelling - Done',
                body: '${widget.fundiName} tapped Start Site Visit',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
          }

          if (isTravelling && !siteDone) {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title: 'Fundi is on the way - Waiting to arrive',
                message:
                    '${widget.fundiName} is travelling to $location. Tracking live. Will turn GREEN when arrives.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerTrackingScreen(jobId: widget.jobId, job: job),
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
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerTrackingScreen(jobId: widget.jobId, job: job),
                    ),
                  ),
                ),
              ),
            );
          } else if (siteDone) {
            timeline.add(
              _timelineCard(
                title: 'Fundi was on the way - Done',
                body: 'Travelling completed',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
          }

          if (siteDone) {
            timeline.add(
              _timelineCard(
                title: 'Fundi arrived - Currently on site - Done',
                body: 'At $location • Inspecting site now - Done',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
          }
          if (!siteDone) {
            return _buildReversedList(timeline);
          }

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
            return _buildReversedList(timeline);
          } else if (reneg != null &&
              reneg['requested'] == true &&
              renegStatus == 'pending') {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title:
                    'Fundi requests price review - Waiting for you to review',
                message:
                    '${reneg['reasonDetails'] ?? 'Fundi sent new breakdown'}\nExtra labor: KES ${_toInt(reneg['extraLabor'])}\nWaiting for you to tap REVIEW BREAKDOWN.',
                action: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
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
              ),
            );
            return _buildReversedList(timeline);
          }

          if (reneg != null &&
              (renegStatus.contains('accepted') ||
                  renegStatus.contains('pending_extra_escrow') ||
                  phase == 'waiting_for_client_to_buy_parts' ||
                  phase == 'fundi_buying_parts')) {
            if (reneg['requested'] == false || renegStatus != 'pending') {
              timeline.add(
                _timelineCard(
                  title: 'Price review - Reviewed - Done',
                  body: 'You reviewed fundi breakdown - Done',
                  icon: Icons.check_circle,
                  isDone: true,
                ),
              );
            }
          }

          if (phase == 'waiting_for_client_to_buy_parts') {
            timeline.add(
              _timelineCard(
                title: 'You will buy parts - Confirm when bought',
                body:
                    'Extra KES ${_toInt(job['extraLaborAmount'])} locked. Buy the listed parts then confirm.',
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
            return _buildReversedList(timeline);
          }
          if (phase == 'client_claims_parts_bought' ||
              phase == 'parts_confirmed_by_fundi' ||
              phase == 'fundi_working' ||
              status == 'in_progress' ||
              status.contains('completed')) {
            if (phase != 'waiting_for_client_to_buy_parts') {
              timeline.add(
                _timelineCard(
                  title: 'You bought parts - Done',
                  body: 'Parts purchase confirmed',
                  icon: Icons.check_circle,
                  isDone: true,
                ),
              );
            }
          }

          if (phase == 'client_claims_parts_bought') {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title: 'Parts bought - Waiting for fundi to confirm',
                message:
                    'You marked parts as bought. Waiting for ${widget.fundiName} to confirm.',
              ),
            );
            return _buildReversedList(timeline);
          } else if (phase == 'parts_confirmed_by_fundi' ||
              phase == 'fundi_working' ||
              status == 'in_progress' ||
              status.contains('completed')) {
            if (phase != 'waiting_for_client_to_buy_parts') {
              timeline.add(
                _timelineCard(
                  title: 'Fundi confirmed parts - Done',
                  body: 'Parts confirmed as available',
                  icon: Icons.check_circle,
                  isDone: true,
                ),
              );
            }
          }

          if (phase == 'parts_confirmed_by_fundi') {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title:
                    'Fundi confirmed parts - Waiting for fundi to start work',
                message:
                    'Fundi confirmed your parts are available. Waiting for him to tap Start Job.',
              ),
            );
            return _buildReversedList(timeline);
          }

          if (status == 'site_visit' && phase.isEmpty) {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title: 'Waiting for fundi to start job',
                message:
                    '${widget.fundiName} arrived at $location and is on site. Waiting for him to Start Job.',
              ),
            );
            return _buildReversedList(timeline);
          } else if (status == 'in_progress' ||
              phase == 'fundi_working' ||
              status.contains('completed')) {
            timeline.add(
              _timelineCard(
                title: 'Waiting for fundi to start job - Done',
                body: 'Fundi started job',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
          }

          if (phase == 'fundi_working' || status == 'in_progress') {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title: 'Fundi is working - Waiting to complete',
                message:
                    '${widget.trade} in progress at $location. ${widget.fundiName} is working. Waiting for him to tap MARK JOB AS COMPLETED.',
              ),
            );
            return _buildReversedList(timeline);
          }
          if (status == 'job_completed' || status == 'pending_completion') {
            bool isDone = status == 'completed';
            int initialAmt = _toInt(
              job['escrowAmount'] ?? job['agreedPrice'] ?? 0,
            );
            int extraAmt = _toInt(
              job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
            );
            int newTotal = _toInt(reneg?['newLaborTotal'] ?? 0);
            int totalToRelease = newTotal > 0
                ? newTotal
                : initialAmt + extraAmt;
            if (totalToRelease == 0) totalToRelease = initialAmt;
            timeline.add(
              _timelineCard(
                title: isDone
                    ? 'Job Completed - KES $totalToRelease released'
                    : 'Job Completed by ${widget.fundiName} - Confirm & Release KES $totalToRelease',
                body: isDone
                    ? 'Payment released'
                    : 'Fundi marked job as complete. Confirm to release KES $totalToRelease',
                icon: Icons.verified,
                isDone: isDone,
                action: !isDone
                    ? SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.greenSuccess,
                          ),
                          onPressed: () =>
                              _confirmCompletion(widget.jobId, fundiId),
                          child: Text(
                            'CONFIRM COMPLETION & RELEASE KES $totalToRelease',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }
          return _buildReversedList(timeline);
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
