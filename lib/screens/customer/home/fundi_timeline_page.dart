import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../customer/confirm/client_price_approval_screen.dart';
import '../tracking/customer_tracking_screen.dart';
import '../../../widgets/animated_waiting_card.dart';
import '../rating/rate_fundi_screen.dart';
import '../../../services/job_cancel_service.dart';

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

  double _toDouble(dynamic v, [double fb = 0]) {
    if (v == null) return fb;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fb;
  }

  bool _toBool(dynamic v, [bool fb = false]) {
    if (v == null) return fb;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return fb;
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
    if (_releasing) return;
    setState(() => _releasing = true);
    try {
      var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
      var snap = await jobRef.get();
      if (!snap.exists) throw 'Job not found';
      var j = snap.data() as Map<String, dynamic>;
      var reneg = j['renegotiation'] as Map<String, dynamic>?;

      int labour = _toInt(j['laborCost'] ?? j['agreedPrice'] ?? 0);
      int transport = _toInt(j['transportFee'] ?? 0);
      int clientAppFee = _toInt(j['clientAppFee'] ?? (labour * 0.05).round());
      int fundiAppFee = _toInt(j['fundiAppFee'] ?? (labour * 0.05).round());
      int totalClient = _toInt(
        j['totalClientPays'] ??
            j['totalCost'] ??
            labour + transport + clientAppFee,
      );
      int fundiReceives = _toInt(
        j['fundiReceives'] ?? labour - fundiAppFee + transport,
      );

      if (reneg != null && reneg['newLaborTotal'] != null) {
        int newLabour = _toInt(reneg['newLaborTotal']);
        int newTotalClient = _toInt(
          reneg['newTotalClientPays'] ??
              newLabour + transport + (newLabour * 0.05).round(),
        );
        int newFundiReceives = _toInt(
          reneg['newFundiReceives'] ??
              newLabour - (newLabour * 0.05).round() + transport,
        );
        totalClient = newTotalClient > 0 ? newTotalClient : totalClient;
        fundiReceives = newFundiReceives > 0 ? newFundiReceives : fundiReceives;
      }

      int alreadyLocked = _toInt(j['escrowAmount'] ?? totalClient);

      await jobRef.update({
        'status': 'completed',
        'escrowStatus': 'released',
        'extraEscrowStatus': 'released',
        'clientConfirmedComplete': true,
        'completedAt': FieldValue.serverTimestamp(),
        'totalReleasedAmount': totalClient,
        'fundiPayoutAmount': fundiReceives,
        'fundiReceives': fundiReceives,
        'totalClientPaid': totalClient,
        'initialEscrowReleased': alreadyLocked,
        'fundiHasUnread': true,
        'customerHasUnread': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseFirestore.instance
            .collection('escrowTransactions')
            .doc(jobId)
            .set({
              'jobId': jobId,
              'fundiId': fundiId,
              'status': 'released',
              'amount': totalClient,
              'fundiPayout': fundiReceives,
              'initialAmount': alreadyLocked,
              'releasedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('escrowTransactions set error $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Released KES $totalClient to Fundi')),
      );
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
    } catch (e) {
      debugPrint('CONFIRM COMPLETION ERROR $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to release: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
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

  Widget _feeRow(String l, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
          ),
          Text(
            v,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelCard({
    required Map<String, dynamic> job,
    required bool isTravelling,
    required bool siteDone,
    required int transport,
  }) {
    bool arrived = isTravelling || siteDone;
    return Card(
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cancel_outlined,
                  size: 18,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cancel this job?',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              arrived
                  ? 'Fundi is on the way/at site. If you cancel: Transport KES $transport -> fundi, you get 95% labour back, 5% fee kept.'
                  : 'Before travelling. You get 95% labour + 100% transport back. 5% labour fee kept for maintenance.',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade400),
                  foregroundColor: Colors.red.shade700,
                ),
                icon: const Icon(Icons.cancel, size: 16),
                label: Text(
                  arrived
                      ? 'CANCEL JOB - 95% LABOUR BACK + TRANSPORT TO FUNDI'
                      : 'CANCEL JOB - 95% LABOUR + 100% TRANSPORT BACK',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () => JobCancelService.showCancelDialog(
                  context: context,
                  jobId: widget.jobId,
                  job: job,
                  isClient: true,
                ),
              ),
            ),
          ],
        ),
      ),
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
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData || snap.data == null || !snap.data!.exists)
            return const Center(child: Text('Job not found'));
          final raw = snap.data!.data();
          if (raw == null) return const Center(child: Text('Job deleted'));
          var job = raw as Map<String, dynamic>;
          var escrow = (job['escrowStatus'] ?? 'pending').toString();
          var status = (job['status'] ?? '').toString();
          var location = (job['location'] ?? job['address'] ?? 'Your location')
              .toString();
          bool siteDone =
              _toBool(job['siteVisitDone']) || _toBool(job['siteVisited']);
          bool isTravelling =
              _toBool(job['travelling']) &&
              _toBool(job['siteVisitStarted']) &&
              !siteDone;
          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          String renegStatus = (reneg?['status'] ?? '').toString();
          String phase = (reneg?['currentPhase'] ?? '').toString();
          bool needsExtraEscrow = renegStatus.contains('pending_extra_escrow');

          int labour = _toInt(
            job['laborCost'] ??
                job['agreedPrice'] ??
                job['acceptedBidAmount'] ??
                0,
          );
          int transport = _toInt(job['transportFee'] ?? 0);
          double km = _toDouble(job['transportDistanceKm'] ?? 0);
          String mode = (job['transportMode'] ?? 'boda').toString();
          String transportLabel = km > 0
              ? 'Transport cost ($mode ${km.toStringAsFixed(1)}km):'
              : 'Transport cost ($mode):';
          int clientAppFee = _toInt(
            job['clientAppFee'] ?? (labour * 0.05).round(),
          );
          int fundiAppFee = _toInt(
            job['fundiAppFee'] ?? (labour * 0.05).round(),
          );
          int totalToPay = _toInt(
            job['totalClientPays'] ??
                job['totalCost'] ??
                labour + transport + clientAppFee,
          );
          int fundiReceives = _toInt(
            job['fundiReceives'] ?? labour - fundiAppFee + transport,
          );
          double agreed = totalToPay.toDouble();

          int alreadyLocked = _toInt(job['escrowAmount'] ?? 0);
          bool escrowHeldFlag =
              _toBool(job['escrowHeld']) || job['escrowPaidAt'] != null;
          bool escrowDone =
              ['held', 'paid', 'released'].contains(escrow) ||
              escrowHeldFlag ||
              alreadyLocked > 0 ||
              status == 'escrow_locked' ||
              status == 'completed';
          bool clientRated = _toBool(job['clientRated']);
          String fundiId =
              (job['fundiId'] ??
                      job['assignedFundiId'] ??
                      job['acceptedBidId'] ??
                      '')
                  .toString();

          bool isStarted =
              status == 'in_progress' ||
              phase == 'fundi_working' ||
              status == 'job_completed' ||
              status == 'pending_completion' ||
              status == 'completed';
          bool isCancelled = [
            'cancelled',
            'cancelled_after_arrival',
          ].contains(status);
          bool canClientCancel = !isStarted && !isCancelled;

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

          if (status == 'completed' && !clientRated) {
            timeline.add(
              _timelineCard(
                title: 'Job completed by ${widget.fundiName} - Done',
                body:
                    'Payment KES ${job['totalReleasedAmount'] ?? alreadyLocked} released. Please rate ${widget.fundiName} to clear this job.\nYou paid: Labour $labour + Transport $transport + App $clientAppFee = $totalToPay',
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
                        'This notification will be cleared only after you rate and review.',
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
                    'You rated ${job['clientRating'] ?? 5} stars - KES ${job['totalReleasedAmount'] ?? alreadyLocked} released. Fundi received $fundiReceives (after app maintenance cost).',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );
            return _buildReversedList(timeline);
          }
          if (isCancelled) {
            timeline.add(
              _timelineCard(
                title: status == 'cancelled_after_arrival'
                    ? 'Job cancelled after arrival'
                    : 'Job cancelled',
                body:
                    'Cancelled by ${job['cancelledBy'] ?? ''} - Refund KES ${job['clientRefund'] ?? ''} - Fee KES ${job['platformFee'] ?? ''} - Fundi gets KES ${job['fundiPayout'] ?? 0}',
                icon: Icons.cancel,
                isDone: false,
              ),
            );
            return _buildReversedList(timeline);
          }

          timeline.add(
            _timelineCard(
              title: 'Bid accepted - Done',
              body: '${widget.trade} • $location',
              icon: Icons.verified,
              isDone: true,
              extra: Column(
                children: [
                  _feeRow('Fundi labour charges:', 'KES $labour'),
                  _feeRow(transportLabel, 'KES $transport'),
                  _feeRow('App maintenance cost:', 'KES $clientAppFee'),
                  Divider(height: 10),
                  _feeRow('Total to pay:', 'KES $totalToPay', bold: true),
                ],
              ),
            ),
          );

          final fundiNameStr =
              (job['assignedFundiName'] ?? job['fundiName'] ?? 'your fundi')
                  .toString();
          timeline.add(
            _timelineCard(
              title: escrowDone
                  ? 'Escrow locked - KES $alreadyLocked secured'
                  : 'Lock KES $totalToPay to escrow now',
              body: escrowDone
                  ? 'KES $alreadyLocked is secured. It will be released to $fundiNameStr after you confirm the job is completed.'
                  : 'This amount will be held in FundiApp and only released to Fundi $fundiNameStr after you confirm the job is completed.',
              icon: Icons.lock,
              isDone: escrowDone,
              action: !escrowDone
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _payEscrow(widget.jobId, agreed),
                      child: Text('Pay KES $totalToPay to Escrow'),
                    )
                  : null,
            ),
          );

          // FIX: Add cancel BEFORE early return so it shows immediately after escrow
          if (!escrowDone) {
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
                ),
              );
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
                    '${widget.fundiName} is travelling to $location. Tracking live.',
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

          if (siteDone)
            timeline.add(
              _timelineCard(
                title: 'Fundi arrived - Currently on site - Done',
                body: 'At $location • Inspecting site now - Done',
                icon: Icons.check_circle,
                isDone: true,
              ),
            );

          if (!siteDone) {
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
                ),
              );
            return _buildReversedList(timeline);
          }

          if (needsExtraEscrow) {
            int extraToLock = _toInt(
              reneg?['extraToLock'] ?? _toInt(job['extraToLock'] ?? 0),
            );
            if (extraToLock == 0) {
              int newTotalClient = _toInt(reneg?['newTotalClientPays'] ?? 0);
              if (newTotalClient > 0)
                extraToLock = newTotalClient - alreadyLocked;
            }
            int newTotalClient = _toInt(
              reneg?['newTotalClientPays'] ?? alreadyLocked + extraToLock,
            );
            timeline.add(
              _timelineCard(
                title: 'Lock extra KES $extraToLock in escrow',
                body:
                    'You accepted new price KES $newTotalClient. Already locked KES $alreadyLocked. Lock extra KES $extraToLock before fundi continues.',
                icon: Icons.lock_open,
                isDone: false,
                action: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _payExtraEscrow(
                    widget.jobId,
                    extraToLock,
                    newTotalClient,
                    renegStatus,
                  ),
                  child: Text('LOCK EXTRA KES $extraToLock NOW'),
                ),
              ),
            );
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
                ),
              );
            return _buildReversedList(timeline);
          } else if (reneg != null &&
              _toBool(reneg['requested']) &&
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
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
                ),
              );
            return _buildReversedList(timeline);
          }

          if (reneg != null &&
              (renegStatus.contains('accepted') ||
                  renegStatus.contains('pending_extra_escrow') ||
                  phase == 'waiting_for_client_to_buy_parts' ||
                  phase == 'fundi_buying_parts')) {
            if (!_toBool(reneg['requested']) || renegStatus != 'pending')
              timeline.add(
                _timelineCard(
                  title: 'Price review - Reviewed - Done',
                  body: 'You reviewed fundi breakdown - Done',
                  icon: Icons.check_circle,
                  isDone: true,
                ),
              );
          }

          if (phase == 'waiting_for_client_to_buy_parts') {
            final oldLabor = _toInt(
              reneg?['oldLabor'] ?? job['laborCost'] ?? job['agreedPrice'] ?? 0,
            );
            final transportVal = _toInt(job['transportFee'] ?? 0);
            final oldClientFee = (oldLabor * 0.05).round();
            final alreadyLockedBase = oldLabor + transportVal + oldClientFee;
            final extraLaborVal = _toInt(
              job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
            );
            final extraAppVal = _toInt(
              job['extraClientAppFee'] ??
                  reneg?['extraApp'] ??
                  (extraLaborVal * 0.05).round(),
            );
            final extraToLockVal = extraLaborVal + extraAppVal;
            final newTotalVal = alreadyLockedBase + extraToLockVal;
            final totalLockedNow = _toInt(job['escrowAmount'] ?? newTotalVal);
            timeline.add(
              _timelineCard(
                title: 'You will buy parts - Confirm when bought',
                body:
                    'Extra KES $extraToLockVal locked (Labour $extraLaborVal + App $extraAppVal). Total locked KES $totalLockedNow. Buy the listed parts then confirm.',
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
          }
          if (phase == 'client_claims_parts_bought' ||
              phase == 'parts_confirmed_by_fundi' ||
              phase == 'fundi_working' ||
              status == 'in_progress' ||
              status.contains('completed')) {
            if (phase != 'waiting_for_client_to_buy_parts')
              timeline.add(
                _timelineCard(
                  title: 'You bought parts - Done',
                  body: 'Parts purchase confirmed',
                  icon: Icons.check_circle,
                  isDone: true,
                ),
              );
          }

          if (phase == 'client_claims_parts_bought') {
            timeline.add(
              OrangeAnimatedWaitingCard(
                title: 'Parts bought - Waiting for fundi to confirm',
                message:
                    'You marked parts as bought. Waiting for ${widget.fundiName} to confirm.',
              ),
            );
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
                ),
              );
            return _buildReversedList(timeline);
          } else if (phase == 'parts_confirmed_by_fundi' ||
              phase == 'fundi_working' ||
              status == 'in_progress' ||
              status.contains('completed')) {
            if (phase != 'waiting_for_client_to_buy_parts')
              timeline.add(
                _timelineCard(
                  title: 'Fundi confirmed parts - Done',
                  body: 'Parts confirmed as available',
                  icon: Icons.check_circle,
                  isDone: true,
                ),
              );
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
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
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
            if (canClientCancel)
              timeline.add(
                _cancelCard(
                  job: job,
                  isTravelling: isTravelling,
                  siteDone: siteDone,
                  transport: transport,
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
            int oldLabour = _toInt(labour);
            int newLabour = _toInt(
              reneg?['newLaborTotal'] ??
                  oldLabour + _toInt(reneg?['extraLabor'] ?? 0),
            );
            int transportVal = _toInt(job['transportFee'] ?? 0);
            int newClientFee = (newLabour * 0.05).round();
            int newTotalClient = newLabour + transportVal + newClientFee;
            int totalToRelease = _toInt(
              reneg?['newTotalClientPays'] ?? newTotalClient,
            );
            timeline.add(
              _timelineCard(
                title:
                    'Job Completed by ${widget.fundiName} - Confirm & Release KES $totalToRelease',
                body:
                    'Fundi marked job as complete. Confirm to release KES $totalToRelease',
                icon: Icons.verified,
                isDone: false,
                extra: Column(
                  children: [
                    _feeRow('Labour:', 'KES $newLabour'),
                    _feeRow('Transport:', 'KES $transportVal'),
                    _feeRow('App Maintenance cost 5%:', 'KES $newClientFee'),
                    Divider(height: 6),
                    _feeRow(
                      'Total you release:',
                      'KES $totalToRelease',
                      bold: true,
                    ),
                  ],
                ),
                action: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.greenSuccess,
                    ),
                    onPressed: _releasing
                        ? null
                        : () => _confirmCompletion(widget.jobId, fundiId),
                    child: _releasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'CONFIRM COMPLETION & RELEASE KES $totalToRelease',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                  ),
                ),
              ),
            );
          }

          // FINAL CANCEL - added last so it appears FIRST after reversal = immediately visible
          if (canClientCancel)
            timeline.add(
              _cancelCard(
                job: job,
                isTravelling: isTravelling,
                siteDone: siteDone,
                transport: transport,
              ),
            );
          if (isStarted)
            timeline.add(
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Job started - Cancel inactive for both. Must complete the job.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );

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
    Widget? extra,
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
              if (extra != null) ...[const SizedBox(height: 6), extra],
              if (action != null) ...[const SizedBox(height: 10), action],
            ],
          ),
        ),
      ),
    );
  }
}
