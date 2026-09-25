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
        int clientAppFee = _toInt(
          job['clientAppFee'] ?? (labour * 0.05).round(),
        );
        int fundiAppFee = _toInt(job['fundiAppFee'] ?? (labour * 0.05).round());
        int totalClientPays = _toInt(
          job['totalClientPays'] ??
              job['totalCost'] ??
              labour + transport + clientAppFee,
        );
        int fundiReceives = _toInt(
          job['fundiReceives'] ??
              job['fundiPayoutAmount'] ??
              labour - fundiAppFee + transport,
        );
        int fundiSeesWaiting = labour + transport;

        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        String phase = (reneg?['currentPhase'] ?? '').toString();
        String rs = (reneg?['status'] ?? '').toString();

        int newLabour = _toInt(reneg?['newLaborTotal'] ?? labour);
        int newClientFee = _toInt(
          reneg?['newClientAppFee'] ?? (newLabour * 0.05).round(),
        );
        int newFundiFee = _toInt(
          reneg?['newFundiAppFee'] ?? (newLabour * 0.05).round(),
        );
        int newTotalClient = _toInt(
          reneg?['newTotalClientPays'] ?? newLabour + transport + newClientFee,
        );
        int newFundiReceives = _toInt(
          reneg?['newFundiReceives'] ?? newLabour - newFundiFee + transport,
        );
        int extraLabour = _toInt(reneg?['extraLabor'] ?? 0);
        int extraToLock = _toInt(
          reneg?['extraToLock'] ??
              reneg?['extraEscrowAmount'] ??
              newTotalClient - totalClientPays,
        );
        if (extraToLock < 0)
          extraToLock = _toInt(job['extraToLock'] ?? extraLabour);

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
                        'KES $releasedAmount Released!',
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
                            Divider(),
                            _feeRow(
                              'Total to receive:',
                              'KES $fundiReceives',
                              bold: true,
                            ),
                            _feeRow('Client paid:', 'KES $totalClientPays'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'KES $releasedAmount has been released by $clientName. Confirm your M-Pesa. Client paid $totalClientPays you get $fundiReceives after fee.',
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
                            'YES, I HAVE RECEIVED KES $releasedAmount',
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
                    'You confirmed receipt: Labour $labour + Transport $transport - App $fundiAppFee = $fundiReceives (Client paid $totalClientPays)',
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
                  'Client $clientName has confirmed you but has NOT locked money yet. You cannot start site visit until escrow is held. (Labour $labour + Transport $transport = $fundiSeesWaiting, client actually pays $totalClientPays inc. app fee)',
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
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to buy materials',
              message:
                  'Client locked extra KES $extraToLock (Labour $newLabour + Transport $transport + App $newClientFee = $newTotalClient). Waiting for ${parts.length} items.',
            ),
          );
        } else if (phase == 'client_claims_parts_bought') {
          timeline.add(
            _card(
              color: Colors.blue.shade50,
              border: Colors.blue,
              icon: Icons.inventory,
              iconColor: Colors.blue.shade800,
              title: 'Client says materials bought',
              message:
                  'Client bought parts. Total locked $totalClientPays. Confirm to show START WORK. You will receive $fundiReceives',
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
              title: 'Waiting for client to lock extra KES $extraToLock',
              message:
                  'You requested extra labour KES $extraLabour. New total client pays KES $newTotalClient = Labour $newLabour + Transport $transport + App $newClientFee. Extra to lock now KES $extraToLock. Client must lock before you start.',
            ),
          );
        } else if (rs == 'pending' || rs == 'countered_by_fundi') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to confirm price review',
              message:
                  'You sent new price: Labour $newLabour + Transport $transport + App $newClientFee = Total KES $newTotalClient (Extra KES $extraToLock). Waiting for $clientName to review.',
            ),
          );
        } else if (phase == 'completed_by_fundi' ||
            status == 'job_completed' ||
            status == 'pending_completion') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Job Completed - Waiting for client confirmation',
              message:
                  'You marked $jobTitle as completed. Waiting for $clientName to confirm and release KES $totalClientPays (You will receive KES $fundiReceives after app fee KES $fundiAppFee).\nReceipt: Labour $labour + Transport $transport + App $clientAppFee = Client pays $totalClientPays, you get $fundiReceives.',
            ),
          );
        } else if (phase == 'parts_confirmed_by_fundi') {
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.check_circle,
              iconColor: Colors.green.shade800,
              title: 'Materials confirmed',
              message:
                  'Press START WORK - Total client locked $totalClientPays, you get $fundiReceives',
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
          timeline.add(
            _card(
              color: Colors.orange.shade50,
              border: Colors.orange,
              icon: Icons.construction,
              iconColor: Colors.orange.shade800,
              title: 'You are working',
              message:
                  'You are working on $jobTitle. Client paid $totalClientPays, you will get $fundiReceives.',
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
                  'Travelling to client - escrow $totalClientPays locked, you get $fundiReceives',
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
              title: 'Escrow locked - Start site visit',
              message:
                  'Client paid KES $totalClientPays to escrow (Labour $labour + Transport $transport + App $clientAppFee). You will receive KES $fundiReceives after fee KES $fundiAppFee.',
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
                    'Next action - Client paid $totalClientPays, you get $fundiReceives',
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
            title:
                'Escrow locked - Done KES $fundiSeesWaiting (Client paid $totalClientPays)',
            message:
                'Client locked KES $totalClientPays (Labour $labour + Transport $transport + App $clientAppFee) - You will receive $fundiReceives after fee $fundiAppFee',
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
                  'Client locked extra KES $extraToLock - Done (Total $newTotalClient)',
              message:
                  'Extra labour $extraLabour + App ${newClientFee - clientAppFee} = $extraToLock locked. New total $newTotalClient, you get $newFundiReceives',
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
                'Labour $labour + Transport $transport = $fundiSeesWaiting waiting label, client pays $totalClientPays',
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
