import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/fundi_request_new_price_screen.dart';
import 'fundi_visit_customer_tab.dart';
import '../../../widgets/animated_waiting_card.dart';
import '../rating/rate_client_screen.dart';
import '../../../services/job_cancel_service.dart';
import '../../../app.dart'; // for HomeNavigator
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/job_chat_section.dart';

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

  void _goBackToMyJobs(BuildContext context, {int tab = 1}) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeNavigator(
          role: 'fundi',
          email: email,
          initialIndex: 2,
          initialJobStatusTab: tab,
        ),
      ),
      (r) => false,
    );
  }

  Future<void> _startSiteVisit(BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'siteVisitStartedAt':
          FieldValue.serverTimestamp(), // <- ADD for 2h30m auto-cancel
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
    final jobSnap = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
    String clientId = '';
    if (jobSnap.exists) {
      var d = jobSnap.data() as Map<String, dynamic>;
      clientId = (d['customerId'] ?? d['clientId'] ?? '').toString();
    }

    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status':
          'parts_confirmed_by_fundi', // FIX: so client sees START WORK next
      'renegotiation.currentPhase': 'parts_confirmed_by_fundi',
      'renegotiation.partsConfirmedByFundi': true,
      'renegotiation.partsConfirmedAt': FieldValue.serverTimestamp(),
      'renegotiation.status': 'parts_confirmed_by_fundi',
      'customerHasUnread': true,
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (clientId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': clientId,
          'toRole': 'client',
          'type': 'parts_confirmed',
          'jobId': jobId,
          'title': 'Fundi confirmed parts',
          'body': 'Fundi confirmed materials available - waiting to start job',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
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
    Map<String, dynamic> job,
  ) async {
    String status = (job['status'] ?? '').toString();
    if (status.toLowerCase().contains('cancel')) {
      _goBackToMyJobs(context, tab: 4);
      return;
    }
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'fundiConfirmedPayment': true,
      'fundiPaymentConfirmedAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RateClientScreen(
          jobId: jobId,
          clientId: clientId,
          clientName: clientName,
          trade: jobTitle,
        ),
      ),
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

        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        String phase = (reneg?['currentPhase'] ?? '').toString();
        String rs = (reneg?['status'] ?? '').toString();

        // FIX: use counter 1000 not raw 2000
        int rawExtra = _toInt(
          reneg?['extraLabor'] ?? job['extraLaborAmount'] ?? 0,
        );
        int counterExtra = _toInt(
          reneg?['acceptedCounterExtraLabor'] ??
              reneg?['counterExtraLabor'] ??
              0,
        );
        int extraLabour = counterExtra > 0 ? counterExtra : rawExtra; // 1000

        int oldLabour = _toInt(reneg?['oldLabor'] ?? 0);
        if (oldLabour == 0) {
          int fromJob = _toInt(job['laborCost'] ?? job['agreedPrice'] ?? 0);
          oldLabour = fromJob > extraLabour ? fromJob - extraLabour : 5000;
        }

        int newLabour = oldLabour + extraLabour; // 5000+1000=6000
        int transport = _toInt(
          job['transportFee'] ?? reneg?['oldTransportFee'] ?? 0,
        );

        // final values used everywhere
        int labour = newLabour; // 6000
        int fundiAppFee = (labour * 0.05).round(); // 300 NOT 250 / 350
        int fundiReceives = labour - fundiAppFee + transport; // 5800 NOT 6750
        int fundiSeesWaiting = labour + transport;

        int newTotalFundiLocked = newLabour + transport;
        int newFundiReceivesVal = fundiReceives;
        bool isCounterAccepted = counterExtra > 0;
        int releasedAmount = fundiReceives;

        String clientId = (job['clientId'] ?? job['customerId'] ?? '')
            .toString();
        bool fundiConfirmedPayment = _toBool(job['fundiConfirmedPayment']);
        bool fundiRatedClient = _toBool(job['fundiRated']);
        bool siteDone =
            _toBool(job['siteVisitDone']) || _toBool(job['siteVisited']);
        bool travelling = _toBool(job['travelling']) || status == 'travelling';
        bool extraPaid = (job['extraEscrowStatus'] ?? '') == 'paid';

        bool isStarted =
            status == 'in_progress' ||
            phase == 'fundi_working' ||
            status == 'job_completed' ||
            status == 'pending_completion' ||
            status == 'completed';
        bool isCancelled = status.toLowerCase().contains('cancel');
        bool canFundiCancel =
            (status == 'assigned' || status == 'confirmed') &&
            !travelling &&
            !siteDone &&
            !isStarted &&
            !isCancelled;

        Widget fixedCancelBtn() {
          return Container(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0x1A000000))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade400),
                  foregroundColor: Colors.red.shade700,
                ),
                onPressed: () => JobCancelService.showCancelDialog(
                  context: context,
                  jobId: jobId,
                  job: job,
                  isClient: false,
                ),
                child: Text(
                  'CANCEL JOB',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }

        Widget buildWithFixedCancel(Widget list) {
          if (!canFundiCancel) return list;
          return Column(
            children: [
              Expanded(child: list),
              fixedCancelBtn(),
            ],
          );
        }

        if (isCancelled) {
          final String title;
          final String message;
          switch (status) {
            case 'cancelled_before_payment':
              title = 'Client cancelled';
              message = 'Client cancelled this job before paying to escrow.';
              break;
            case 'auto_cancelled_no_arrival':
              title = 'Auto-cancelled - No arrival - No payout';
              message = 'You did not arrive in time. Client got full refund.';
              break;
            case 'cancelled_after_arrival':
              title =
                  'Cancelled after arrival - Transport KES $transport to you';
              message =
                  'Cancelled by ${job['cancelledBy'] ?? ''} - Reason: ${job['cancelledBy'] ?? ''} ${job['cancelReason'] ?? ''}';
              break;
            default:
              title = 'Cancelled - Full refund to client';
              message =
                  'Cancelled by ${job['cancelledBy'] ?? ''} - Reason: ${job['cancelReason'] ?? ''}';
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBackToMyJobs(
                  context,
                  tab: 2,
                ), // use tab 4 for cancelled, tab 3 for completed, tab 1 for escrow-not-done
              ),
              title: Text(
                clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: 'Chat',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (context, scrollCtrl) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chat with $clientName',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.all(12),
                                  child: JobChatSection(
                                    jobId: jobId,
                                    isClient: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _card(
                  color: Colors.red.shade50,
                  border: Colors.red,
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                  title: title,
                  message: message,
                  time: 'Now',
                  isDone: false,
                ),
                // NEW: If this cancelled job was reposted, show button to view new job
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('jobs')
                      .where('repostedFrom', isEqualTo: jobId)
                      .where(
                        'status',
                        whereIn: [
                          'open',
                          'assigned',
                          'confirmed',
                          'travelling',
                          'site_visit',
                          'in_progress',
                        ],
                      )
                      .limit(1)
                      .get(),
                  builder: (ctx, repSnap) {
                    if (!repSnap.hasData || repSnap.data!.docs.isEmpty)
                      return const SizedBox();
                    var newDoc = repSnap.data!.docs.first;
                    return Card(
                      color: Colors.green.shade50,
                      child: ListTile(
                        title: Text(
                          'Client reposted this job',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Text(
                          'New job is open for bidding again',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FundiCustomerTimelinePage(
                                jobId: newDoc.id,
                                clientName: clientName,
                                jobTitle: jobTitle,
                              ),
                            ),
                          ),
                          child: const Text('VIEW NEW JOB'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }

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
                            _feeRow('Labour cost:', 'KES $labour'), // 6000
                            _feeRow('Transport:', '+ KES $transport'), // +100
                            _feeRow(
                              'App maintenance cost:',
                              '- KES $fundiAppFee',
                            ), // -300 FIX was -250 / -350
                            const Divider(),
                            _feeRow(
                              'Total to receive:',
                              'KES $releasedAmount',
                              bold: true,
                            ), // 5800 NOT 6750
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
                              _confirmPaymentReceived(context, clientId, job),
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
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RateClientScreen(
                                jobId: jobId,
                                clientId: clientId,
                                clientName: clientName,
                                trade: jobTitle,
                              ),
                            ),
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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBackToMyJobs(
                  context,
                  tab: 2,
                ), // use tab 4 for cancelled, tab 3 for completed, tab 1 for escrow-not-done
              ),
              title: Text(
                clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: 'Chat',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (context, scrollCtrl) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chat with $clientName',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.all(12),
                                  child: JobChatSection(
                                    jobId: jobId,
                                    isClient: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
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
          Widget list = ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: timeline.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => timeline[i],
          );
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBackToMyJobs(
                  context,
                  tab: 2,
                ), // use tab 4 for cancelled, tab 3 for completed, tab 1 for escrow-not-done
              ),
              title: Text(
                clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  tooltip: 'Chat',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        minChildSize: 0.5,
                        maxChildSize: 0.95,
                        builder: (context, scrollCtrl) => Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chat with $clientName',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.all(12),
                                  child: JobChatSection(
                                    jobId: jobId,
                                    isClient: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: buildWithFixedCancel(list),
          );
        }

        //... rest of your timeline logic stays same, just fix back button at the end
        if (phase == 'waiting_for_client_to_buy_parts' ||
            status == 'waiting_for_client_to_buy_parts') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to buy materials',
              message:
                  'Client locked extra labour KES $extraLabour (counter $counterExtra accepted). Total locked KES $newTotalFundiLocked. Waiting for materials.',
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
              message: 'Client bought parts. Confirm to show START WORK.',
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
        } else if (rs == 'countered_by_client') {
          // FIX: Client countered your 2000 -> 1000 - fundi must see Accept/Counter
          int originalExtra = rawExtra;
          int counterExtraClient = _toInt(reneg?['counterExtraLabor'] ?? 0);
          int counterToLockClient = _toInt(
            reneg?['counterExtraToLock'] ??
                counterExtraClient + (counterExtraClient * 0.05).round(),
          );
          timeline.add(
            _card(
              color: Colors.orange.shade50,
              border: Colors.orange,
              icon: Icons.compare_arrows,
              iconColor: Colors.orange.shade800,
              title:
                  'Client countered extra KES $originalExtra with KES $counterExtraClient',
              message:
                  'You requested KES $originalExtra. Client countered with KES $counterExtraClient. Accept to proceed with KES $counterExtraClient.',
              time: 'Now',
              isCurrent: true,
              action: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: () async {
                        int oldLab = _toInt(reneg?['oldLabor'] ?? labour);
                        int oldTrans = _toInt(
                          reneg?['oldTransportFee'] ?? transport,
                        );
                        int alreadyLocked =
                            oldLab + oldTrans + (oldLab * 0.05).round();
                        int newLabTotal =
                            oldLab + counterExtraClient; // 5000+1000=6000
                        int newTotalClient =
                            alreadyLocked +
                            counterToLockClient; // 5350+1050=6400
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(jobId)
                            .update({
                              'renegotiation.acceptedCounterExtraLabor':
                                  counterExtraClient, // 1000 FUNDI SEES 1000
                              'renegotiation.acceptedCounterExtraToLock':
                                  counterToLockClient, // 1050 CLIENT SEES 1050
                              'renegotiation.acceptedCounterExtraAppFee':
                                  (counterExtraClient * 0.05).round(),
                              'renegotiation.newLaborTotal': newLabTotal,
                              'renegotiation.newTotalClientPays':
                                  newTotalClient,
                              'renegotiation.extraToLock': counterToLockClient,
                              'renegotiation.extraLabor': counterExtraClient,
                              'renegotiation.newClientAppFee':
                                  (newLabTotal * 0.05).round(),
                              'renegotiation.newFundiAppFee':
                                  (newLabTotal * 0.05).round(),
                              'renegotiation.status':
                                  'accepted_counter_pending_extra_escrow',
                              'renegotiation.currentPhase':
                                  'waiting_for_extra_escrow',
                              'renegotiation.acceptedCounterAt':
                                  FieldValue.serverTimestamp(),
                              'status': 'awaiting_extra_escrow',
                              'agreedPrice': newLabTotal,
                              'laborCost': newLabTotal,
                              'totalClientPays': newTotalClient,
                              'extraLaborAmount': counterExtraClient,
                              'extraToLock': counterToLockClient,
                              'fundiHasUnread': false,
                              'customerHasUnread': true,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                      },
                      child: Text('ACCEPT KES $counterExtraClient'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
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
                      child: const Text('COUNTER AGAIN'),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (rs.contains('pending_extra_escrow')) {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: isCounterAccepted
                  ? 'You accepted counter KES $extraLabour - Waiting for client to lock extra KES $extraLabour'
                  : 'Waiting for client to lock extra KES $extraLabour',
              message: isCounterAccepted
                  ? 'You accepted client counter of KES $extraLabour. New total KES $newTotalFundiLocked = Labour $newLabour + Transport $transport. Waiting for client to lock.'
                  : 'You requested extra labour KES $extraLabour. New total KES $newTotalFundiLocked = Labour $newLabour + Transport $transport.',
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
          //... keep your existing completed_by_fundi UI (omitted for brevity, paste your old code here)
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Job Completed - Waiting for $clientName to confirm',
              message:
                  'You marked $jobTitle as completed. Waiting for $clientName to confirm and release payment.',
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
              message: 'Press START WORK',
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
              message: 'You are working on $jobTitle.',
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
              message: 'Travelling to client',
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
                  'Labour KES $labour + Transport KES $transport = KES $fundiSeesWaiting locked.',
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
        if (extraPaid)
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
        if (siteDone)
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

        Widget list = ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: timeline.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => timeline[i],
        );
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _goBackToMyJobs(
                context,
                tab: 2,
              ), // use tab 4 for cancelled, tab 3 for completed, tab 1 for escrow-not-done
            ),
            title: Text(
              clientName,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            backgroundColor: FundipapColors.blackGray,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Chat',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    builder: (_) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.85,
                      minChildSize: 0.5,
                      maxChildSize: 0.95,
                      builder: (context, scrollCtrl) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Chat with $clientName',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Divider(),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollCtrl,
                                padding: const EdgeInsets.all(12),
                                child: JobChatSection(
                                  jobId: jobId,
                                  isClient: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: buildWithFixedCancel(list),
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
