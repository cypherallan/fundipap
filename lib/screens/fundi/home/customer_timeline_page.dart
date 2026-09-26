import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/request_new_price.dart';
import 'visit_customer_tab.dart';
import '../../../widgets/animated_waiting_card.dart';
import '../rating/rate_client_screen.dart';

class FundiCustomerTimelinePage extends StatelessWidget {
  final String jobId;
  final String clientName;
  final String jobTitle;
  const FundiCustomerTimelinePage({
    super.key,
    required this.jobId,
    required this.clientName,
    required this.jobTitle,
  });

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
    if (v is double) return v != 0;
    if (v is String) {
      var s = v.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return fb;
  }

  Future<void> _startSiteVisit(BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VisitCustomerScreen(jobId: jobId, job: {'title': jobTitle}),
      ),
    );
  }

  Future<void> _confirmPartsAvailable() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.currentPhase': 'parts_confirmed_by_fundi',
      'renegotiation.partsConfirmedByFundi': true,
      'renegotiation.partsConfirmedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _startJob() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'renegotiation.currentPhase': 'fundi_working',
      'workStartedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _completeJob() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'job_completed',
      'renegotiation.currentPhase': 'completed_by_fundi',
      'completedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmPaymentReceived(
    BuildContext context,
    String clientId,
  ) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'fundiConfirmedPayment': true,
      'fundiPaymentConfirmedAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RateClientScreen(
          jobId: jobId,
          clientId: clientId,
          clientName: clientName,
          trade: jobTitle,
        ),
      ),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        var job = snap.data!.data() as Map<String, dynamic>;
        var status = (job['status'] ?? '').toString();
        var escrow = (job['escrowStatus'] ?? 'pending').toString();
        bool escrowDone =
            escrow == 'held' || escrow == 'paid' || escrow == 'released';
        bool escrowReleased = escrow == 'released' || status == 'completed';

        int labour = _toInt(
          job['laborCost'] ??
              job['agreedPrice'] ??
              job['acceptedBidAmount'] ??
              job['fundiBidAmount'] ??
              job['budget'] ??
              0,
        );
        int transport = _toInt(job['transportFee'] ?? 0);
        int fundiAppFee = _toInt(job['fundiAppFee'] ?? (labour * 0.05).round());
        int fundiReceives = _toInt(
          job['fundiReceives'] ??
              job['fundiPayoutAmount'] ??
              labour - fundiAppFee + transport,
        );
        int fundiSeesWaiting = labour + transport; // 5100 FUNDI VIEW

        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        String phase = (reneg?['currentPhase'] ?? '').toString();
        String rs = (reneg?['status'] ?? '').toString();

        int newLabour = _toInt(reneg?['newLaborTotal'] ?? labour); // 6000
        int newFundiFee = _toInt(
          reneg?['newFundiAppFee'] ?? (newLabour * 0.05).round(),
        ); // 300
        int extraLabour = _toInt(
          reneg?['extraLabor'] ?? job['extraLaborAmount'] ?? 0,
        ); // 1000 FUNDI
        int newTotalFundiLocked = newLabour + transport; // 6100 FUNDI
        int newFundiReceivesVal = newLabour - newFundiFee + transport; // 5800

        int releasedAmount = _toInt(
          job['fundiPayoutAmount'] ??
              job['totalReleasedAmount'] ??
              fundiReceives,
        );
        String clientId = (job['clientId'] ?? job['customerId'] ?? '')
            .toString();
        bool fundiConfirmedPayment = _toBool(job['fundiConfirmedPayment']);
        bool fundiRatedClient = _toBool(job['fundiRated']);
        bool siteDone =
            _toBool(job['siteVisitDone']) || _toBool(job['siteVisited']);
        bool travelling = _toBool(job['travelling']) || status == 'travelling';
        bool extraPaid = (job['extraEscrowStatus'] ?? '') == 'paid';
        List parts = List.from(reneg?['partsNeeded'] ?? []);

        if (status == 'completed' && escrowReleased) {
          List<Widget> doneTimeline = [];
          if (!fundiConfirmedPayment) {
            doneTimeline.add(
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.green.shade700, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        size: 48,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES $fundiReceives Released!',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _feeRow('Labour cost:', 'KES $labour'),
                            _feeRow('Transport:', '+ KES $transport'),
                            _feeRow(
                              'App maintenance cost:',
                              '- KES $fundiAppFee',
                            ),
                            const Divider(),
                            _feeRow(
                              'Total to receive:',
                              'KES $fundiReceives',
                              bold: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES $fundiReceives has been released by $clientName. Confirm your M-Pesa.',
                        style: GoogleFonts.inter(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.greenSuccess,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              _confirmPaymentReceived(context, clientId),
                          child: Text(
                            'YES, I HAVE RECEIVED KES $fundiReceives',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else if (!fundiRatedClient) {
            doneTimeline.add(
              _card(
                color: Colors.green.shade50,
                border: Colors.green,
                icon: Icons.account_balance_wallet,
                iconColor: Colors.green,
                title: 'KES $releasedAmount confirmed - Done',
                message:
                    'You confirmed receipt: Labour KES $labour + Transport KES $transport - App KES $fundiAppFee = KES $fundiReceives',
                time: 'Done',
                isDone: true,
              ),
            );
            doneTimeline.add(
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
                      Text(
                        'Rate $clientName - Mandatory',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Mandatory to clear this job.',
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
                          onPressed: () =>
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => RateClientScreen(
                                    jobId: jobId,
                                    clientId: clientId,
                                    clientName: clientName,
                                    trade: jobTitle,
                                  ),
                                ),
                                (r) => false,
                              ),
                          child: Text(
                            'RATE $clientName NOW',
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
          } else {
            doneTimeline.add(
              _card(
                color: Colors.green.shade50,
                border: Colors.green,
                icon: Icons.check_circle,
                iconColor: Colors.green,
                title: 'Completed & Rated - Done',
                message:
                    'KES $releasedAmount received and client rated - cleared',
                time: 'Done',
                isDone: true,
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(
                clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
            ),
            body: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: doneTimeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => doneTimeline[i],
            ),
          );
        }

        List<Widget> timeline = [];
        if (!escrowDone) {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title:
                  'Waiting for client to pay KES $fundiSeesWaiting to escrow',
              message:
                  'Client $clientName has confirmed you but has NOT locked money yet. You cannot start site visit until escrow is held.\n\nLabour KES $labour + Transport KES $transport = KES $fundiSeesWaiting',
            ),
          );
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.check_circle,
              iconColor: Colors.green,
              title: 'Bid accepted - Done',
              message: 'Done',
              time: 'Earlier',
              isDone: true,
            ),
          );
          return Scaffold(
            appBar: AppBar(
              title: Text(
                clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
            ),
            body: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: timeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => timeline[i],
            ),
          );
        }

        if (phase == 'waiting_for_client_to_buy_parts') {
          final oldLabor = _toInt(
            reneg?['oldLabor'] ?? job['agreedPrice'] ?? job['laborCost'] ?? 0,
          ); // 5000
          final extraLabourInner = _toInt(
            job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
          ); // 1000
          final fundiOldLocked = oldLabor + transport; // 5100
          final fundiNewLocked = fundiOldLocked + extraLabourInner; // 6100
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to buy materials',
              message:
                  'Client locked extra labour KES $extraLabourInner. Total locked KES $fundiNewLocked. Waiting for ${parts.length} items to be delivered.',
            ),
          );
        } else if (phase == 'client_claims_parts_bought') {
          final oldLabour = _toInt(
            job['agreedPrice'] ?? job['laborCost'] ?? 5000,
          );
          final newLabourInner = _toInt(
            reneg?['newLaborTotal'] ??
                oldLabour +
                    _toInt(
                      job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
                    ),
          );
          final extraLabourInner = _toInt(
            job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
          );
          final newTotalFundiLockedInner = newLabourInner + transport;
          timeline.add(
            _card(
              color: Colors.blue.shade50,
              border: Colors.blue,
              icon: Icons.inventory,
              iconColor: Colors.blue.shade800,
              title: 'Client says materials bought',
              message:
                  'Client bought parts. Total locked KES $newTotalFundiLockedInner secured (Extra $extraLabourInner). Confirm to show START WORK.',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _confirmPartsAvailable,
                child: const Text(
                  'CONFIRM MATERIALS AVAILABLE',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        } else if (rs.contains('pending_extra_escrow')) {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to lock extra KES $extraLabour',
              message:
                  'You requested extra labour KES $extraLabour. New total KES $newTotalFundiLocked = Labour $newLabour + Transport $transport. Extra to lock now KES $extraLabour. Client must lock before you start.',
            ),
          );
        } else if (rs == 'pending' || rs == 'countered_by_fundi') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to confirm price review',
              message:
                  'You requested new labour charge KES $extraLabour. Waiting for $clientName to review.',
            ),
          );
        } else if (phase == 'completed_by_fundi' ||
            status == 'job_completed' ||
            status == 'pending_completion') {
          final oldLabour = _toInt(
            reneg?['oldLabor'] ??
                job['agreedPrice'] ??
                job['laborCost'] ??
                5000,
          );
          final newLabourInner = _toInt(
            reneg?['newLaborTotal'] ??
                oldLabour +
                    _toInt(
                      job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
                    ),
          );
          final extraLabourInner = (newLabourInner - oldLabour).clamp(
            0,
            999999,
          );
          final newFundiFeeInner = (newLabourInner * 0.05).round();
          final totalCustomerLocked = newLabourInner + transport;
          final fundiReceivesInner =
              newLabourInner - newFundiFeeInner + transport;
          Widget receiptRow(
            String label,
            String value, {
            bool bold = false,
            bool total = false,
            bool deduct = false,
          }) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                      color: total ? Colors.green.shade800 : Colors.black87,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                      color: deduct
                          ? Colors.red
                          : total
                          ? Colors.green.shade800
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }

          timeline.add(
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade800,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Job Completed - Waiting for confirmation',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You marked $jobTitle as completed. Waiting for $clientName to confirm.',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        receiptRow('Old Labour', 'KES $oldLabour'),
                        receiptRow('Extra Labour', '+ KES $extraLabourInner'),
                        receiptRow(
                          'New Labour',
                          'KES $newLabourInner',
                          bold: true,
                        ),
                        receiptRow('Transport', 'KES $transport'),
                        const Divider(),
                        receiptRow(
                          'Customer Locked',
                          'KES $totalCustomerLocked',
                          bold: true,
                        ),
                        receiptRow(
                          'Your App Maintenance cost (5%)',
                          '- KES $newFundiFeeInner',
                          deduct: true,
                        ),
                        const Divider(thickness: 1.5),
                        receiptRow(
                          'YOU RECEIVE',
                          'KES $fundiReceivesInner',
                          bold: true,
                          total: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (phase == 'parts_confirmed_by_fundi') {
          final newLabourInner = _toInt(
            reneg?['newLaborTotal'] ??
                labour +
                    _toInt(
                      job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
                    ),
          );
          final newFundiFeeInner = (newLabourInner * 0.05).round();
          final totalCustomerLocked = newLabourInner + transport;
          final fundiReceivesInner =
              newLabourInner - newFundiFeeInner + transport;
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.check_circle,
              iconColor: Colors.green.shade800,
              title: 'Materials confirmed',
              message:
                  'Press START WORK - Customer locked KES $totalCustomerLocked secured, you get KES $fundiReceivesInner after app maintenance cost.',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _startJob,
                child: const Text(
                  'START WORK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        } else if (status == 'in_progress' || phase == 'fundi_working') {
          final newLabourInner = _toInt(
            reneg?['newLaborTotal'] ??
                labour +
                    _toInt(
                      job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
                    ),
          );
          final newFundiFeeInner = (newLabourInner * 0.05).round();
          final totalCustomerLocked = newLabourInner + transport;
          final fundiReceivesInner =
              newLabourInner - newFundiFeeInner + transport;
          timeline.add(
            _card(
              color: Colors.orange.shade50,
              border: Colors.orange,
              icon: Icons.construction,
              iconColor: Colors.orange.shade800,
              title: 'You are working',
              message:
                  'You are working on $jobTitle. Customer locked KES $totalCustomerLocked, you will get KES $fundiReceivesInner after fee.',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.greenSuccess,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _completeJob,
                child: const Text(
                  'MARK JOB AS COMPLETED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        } else if (!siteDone && travelling) {
          timeline.add(
            _card(
              color: Colors.blue.shade50,
              border: Colors.blue,
              icon: Icons.directions_bike,
              iconColor: Colors.blue,
              title: 'You are on the way',
              message:
                  'Travelling to client - escrow KES $fundiSeesWaiting locked, you get KES $fundiReceives',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('OPEN MAP'),
                onPressed: () => _startSiteVisit(context),
              ),
            ),
          );
        } else if (!siteDone) {
          timeline.add(
            _card(
              color: Colors.white,
              border: FundipapColors.blackGray,
              icon: Icons.location_on,
              iconColor: Colors.black,
              title: 'Escrow locked - Done KES $fundiSeesWaiting',
              message:
                  'Labour KES $labour + Transport KES $transport = KES $fundiSeesWaiting locked. You will receive KES $fundiReceives after fee KES $fundiAppFee',
              time: 'Now',
              isCurrent: true,
              action: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FundipapColors.blackGray,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text('START SITE VISIT'),
                  onPressed: () => _startSiteVisit(context),
                ),
              ),
            ),
          );
        } else if (siteDone &&
            (status == 'site_visit' ||
                status == 'assigned' ||
                status == 'confirmed')) {
          timeline.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FundipapColors.greenSuccess,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next action - Client locked KES $fundiSeesWaiting secured to escrow',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startJob,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.greenSuccess,
                          ),
                          child: const Text(
                            'START JOB',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FundiRequestNewPriceScreen(
                                jobId: jobId,
                                job: job,
                              ),
                            ),
                          ),
                          child: const Text('New Price'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        timeline.add(
          _card(
            color: Colors.green.shade50,
            border: Colors.green,
            icon: Icons.lock,
            iconColor: Colors.green,
            title: 'Escrow locked - Done KES $fundiSeesWaiting',
            message:
                'Labour KES $labour + Transport KES $transport = KES $fundiSeesWaiting locked. You will receive KES $fundiReceives after fee KES $fundiAppFee',
            time: 'Done',
            isDone: true,
          ),
        );
        if (extraPaid) {
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.lock_open,
              iconColor: Colors.green.shade800,
              title:
                  'Client locked extra KES $extraLabour - Done (Total $newTotalFundiLocked)',
              message:
                  'Extra labour KES $extraLabour locked. New total KES $newTotalFundiLocked, you get KES $newFundiReceivesVal',
              time: 'Done',
              isDone: true,
            ),
          );
        }
        if (siteDone) {
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.location_on,
              iconColor: Colors.green,
              title: 'Site visited - Done',
              message: 'Done',
              time: 'Done',
              isDone: true,
            ),
          );
        }
        timeline.add(
          _card(
            color: Colors.green.shade50,
            border: Colors.green,
            icon: Icons.check_circle,
            iconColor: Colors.green,
            title: 'Bid accepted - Done',
            message:
                'Labour KES $labour + Transport KES $transport = KES $fundiSeesWaiting locked',
            time: 'Earlier',
            isDone: true,
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              clientName,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            backgroundColor: FundipapColors.blackGray,
            foregroundColor: Colors.white,
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: timeline.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => timeline[i],
          ),
        );
      },
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

  Widget _card({
    required Color color,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String time,
    bool isDone = false,
    bool isCurrent = false,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: iconColor,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                    if (isDone)
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: GoogleFonts.inter(fontSize: 11)),
                if (action != null) ...[const SizedBox(height: 10), action],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
