import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animated_waiting_card.dart';
import '../../../../app.dart';
import '../../../../widgets/job_chat_section.dart';
import '../../../../services/fundi_waiting_state_service.dart';
import '../timeline/fundi_timeline_actions.dart';
import 'widgets/timeline_card.dart';
import '../../my_jobs/fundi_request_new_price_screen.dart';
import '../fundi_visit_customer_tab.dart';

class FundiCustomerTimelinePage extends StatefulWidget {
  final String jobId;
  final String clientName;
  final String jobTitle;
  const FundiCustomerTimelinePage({
    super.key,
    required this.jobId,
    required this.clientName,
    required this.jobTitle,
  });
  @override
  State<FundiCustomerTimelinePage> createState() =>
      _FundiCustomerTimelinePageState();
}

class _FundiCustomerTimelinePageState extends State<FundiCustomerTimelinePage> {
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
    if (v is Timestamp) return true;
    return fb;
  }

  void _goBack(int tab) {
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

  Future<void> counterAsFundi(
    DocumentReference bidRef,
    String jobId,
    double currentPrice,
  ) async {
    final ctrl = TextEditingController(text: currentPrice.toString());
    final msgCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Counter Offer',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New price KES'),
            ),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason / breakdown',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (res != true) return;
    double newPrice = double.tryParse(ctrl.text) ?? currentPrice;
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    await bidRef.collection('counterOffers').add({
      'price': newPrice,
      'by': uid,
      'byName': userDoc.data()?['username'] ?? 'Fundi',
      'message': msgCtrl.text.trim(),
      'at': FieldValue.serverTimestamp(),
    });
    await bidRef.update({
      'status': 'countered',
      'lastCounterPrice': newPrice,
      'lastCounterAmount': newPrice,
      'lastCounterBy': uid,
      'counterBy': uid,
      'lastCounterAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'negotiating',
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': newPrice,
          'by': uid,
          'type': 'counter_fundi',
          'at': DateTime.now().toIso8601String(),
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
    });
  }

  Widget _greenCard({
    required String title,
    required String message,
    IconData icon = Icons.check_circle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: GoogleFonts.inter(fontSize: 11)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 12,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, jobSnap) {
        if (!jobSnap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        var job = jobSnap.data!.data() as Map<String, dynamic>;
        var status = (job['status'] ?? '').toString().toLowerCase();
        var escrowStatus = (job['escrowStatus'] ?? 'pending')
            .toString()
            .toLowerCase();
        bool escrowDone = ['held', 'paid', 'released'].contains(escrowStatus);
        int labour = _toInt(
          job['laborCost'] ?? job['agreedPrice'] ?? job['price'] ?? 0,
        );
        int transport = _toInt(job['transportFee'] ?? 0);
        int fundiSees = labour + transport;
        bool siteDone =
            _toBool(job['siteVisitDone']) ||
            _toBool(job['siteVisited']) ||
            job['siteVisitedAt'] != null ||
            ['site_visit', 'site_visit_done'].contains(status);
        bool isCancelled = status.contains('cancel');

        if (isCancelled) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBack(4),
              ),
              title: Text(
                widget.clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _greenCard(
                  title: 'Cancelled - $status',
                  message:
                      'Cancelled by ${job['cancelledBy'] ?? ''} Reason: ${job['cancelReason'] ?? ''}',
                  icon: Icons.cancel,
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.jobId)
              .collection('bids')
              .where('fundiId', isEqualTo: uid)
              .snapshots(),
          builder: (context, bidsSnap) {
            if (!bidsSnap.hasData)
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            if (bidsSnap.data!.docs.isEmpty) {
              List<Widget> timeline = [];
              timeline.add(
                _greenCard(
                  title: 'Bid sent - KES $labour - Done',
                  message: '${widget.jobTitle} • ${widget.clientName}',
                ),
              );
              if (escrowDone)
                timeline.add(
                  _greenCard(
                    title: 'Escrow locked - Done KES $fundiSees',
                    message:
                        'Labour KES $labour + Transport KES $transport = KES $fundiSees locked',
                  ),
                );
              else
                timeline.add(
                  OrangeAnimatedWaitingCard(
                    title: 'Waiting for client to pay KES $fundiSees to escrow',
                    message:
                        'Client ${widget.clientName} has not locked money yet',
                  ),
                );
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => _goBack(2),
                  ),
                  title: Text(
                    widget.clientName,
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

            var bidDoc = bidsSnap.data!.docs.first;
            var bid = bidDoc.data() as Map<String, dynamic>;
            int myBidPrice = _toInt(bid['price'] ?? 0);

            return StreamBuilder<QuerySnapshot>(
              stream: bidDoc.reference
                  .collection('counterOffers')
                  .orderBy('at', descending: false)
                  .snapshots(),
              builder: (context, coSnap) {
                List<DocumentSnapshot> coDocs = coSnap.data?.docs ?? [];
                List<Map<String, dynamic>> priceHistory =
                    (job['priceHistory'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];

                FundiWaitingState? waitingState = getFundiWaitingState(
                  job: job,
                  bid: bid,
                  counterOffers: coDocs,
                  uid: uid,
                );
                List<Widget> doneHistory = [];
                Widget? currentWaiting;

                for (int i = 0; i < coDocs.length; i++) {
                  var co = coDocs[i].data() as Map<String, dynamic>;
                  int price = _toInt(co['price'] ?? 0);
                  String by = (co['by'] ?? '').toString();
                  bool isLast = i == coDocs.length - 1;
                  if (isLast &&
                      ((by != uid &&
                              waitingState?.type ==
                                  FundiWaitingType.clientCounter) ||
                          (by == uid &&
                              waitingState?.type ==
                                  FundiWaitingType.myCounter)))
                    continue;
                  if (by != uid)
                    doneHistory.add(
                      _greenCard(
                        title: 'Client countered - KES $price - Done',
                        message:
                            'Client ${widget.clientName} countered KES $price • You reacted',
                        icon: Icons.compare_arrows,
                      ),
                    );
                  else
                    doneHistory.add(
                      _greenCard(
                        title: 'You countered - KES $price - Done',
                        message: 'You countered KES $price • Client reacted',
                        icon: Icons.compare_arrows,
                      ),
                    );
                }

                if (waitingState == null ||
                    waitingState.type != FundiWaitingType.bidSent) {
                  doneHistory.add(
                    _greenCard(
                      title: 'Bid sent - KES $myBidPrice - Done',
                      message:
                          'You sent bid KES $myBidPrice for ${widget.jobTitle} • ${widget.clientName}',
                    ),
                  );
                }
                for (var ph in priceHistory) {
                  if ((ph['type'] ?? '') == 'accepted_client_counter') {
                    doneHistory.add(
                      _greenCard(
                        title:
                            'You accepted client counter KES ${_toInt(ph['price'])} - Done',
                        message:
                            'You accepted KES ${_toInt(ph['price'])} • Job assigned',
                      ),
                    );
                  }
                }
                if (escrowDone && !siteDone) {
                  // Don't add green escrow here if waitingState says waiting - waiting card will show orange
                  if (waitingState?.type != FundiWaitingType.waitingEscrow) {
                    doneHistory.add(
                      _greenCard(
                        title: 'Escrow locked - Done KES $fundiSees',
                        message:
                            'Labour KES $labour + Transport KES $transport = KES $fundiSees locked',
                      ),
                    );
                  }
                }
                if (siteDone) {
                  doneHistory.add(
                    _greenCard(
                      title: 'Site visited - Done',
                      message: 'You visited site • Done',
                    ),
                  );
                }

                // BUILD CURRENT WAITING BASED ON SERVICE - ORDER MATTERS
                if (waitingState != null) {
                  switch (waitingState.type) {
                    case FundiWaitingType.clientCounter:
                      int clientCounterAmt = waitingState.price;
                      currentWaiting = Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.compare_arrows,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Client countered your labour charges',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Client countered: KES $clientCounterAmt (Your bid KES $myBidPrice)',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await bidDoc.reference.update({
                                        'status': 'rejected',
                                        'rejectedBy': uid,
                                        'rejectedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                    },
                                    child: Text(
                                      'Reject',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => counterAsFundi(
                                      bidDoc.reference,
                                      widget.jobId,
                                      clientCounterAmt.toDouble(),
                                    ),
                                    child: Text(
                                      'Counter',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          FundipapColors.greenSuccess,
                                    ),
                                    onPressed: () async {
                                      await bidDoc.reference.update({
                                        'status': 'accepted',
                                        'agreedPrice': clientCounterAmt,
                                        'price': clientCounterAmt,
                                        'lastCounterPrice': clientCounterAmt,
                                        'lastCounterAmount': clientCounterAmt,
                                        'acceptedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                      await FirebaseFirestore.instance
                                          .collection('jobs')
                                          .doc(widget.jobId)
                                          .update({
                                            'status': 'assigned',
                                            'assignedFundiId': uid,
                                            'agreedPrice': clientCounterAmt,
                                            'price': clientCounterAmt,
                                            'escrowStatus':
                                                'pending', // FIX: reset so orange waiting shows, not green
                                            'escrowAmount': FieldValue.delete(),
                                            'travelling': false,
                                            'siteVisitDone': false,
                                            'siteVisited': false,
                                            'renegotiation': {
                                              'requested': false,
                                            },
                                            'priceHistory': FieldValue.arrayUnion(
                                              [
                                                {
                                                  'price': clientCounterAmt,
                                                  'by': uid,
                                                  'type':
                                                      'accepted_client_counter',
                                                  'at': DateTime.now()
                                                      .toIso8601String(),
                                                },
                                              ],
                                            ),
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                    },
                                    child: const Text(
                                      'Accept',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                      break;
                    case FundiWaitingType.myCounter:
                    case FundiWaitingType.bidSent:
                    case FundiWaitingType.waitingEscrow:
                    case FundiWaitingType.waitingNewPriceApproval:
                      currentWaiting = OrangeAnimatedWaitingCard(
                        title: waitingState.title,
                        message: waitingState.message,
                      );
                      break;
                    case FundiWaitingType.escrowLocked:
                      currentWaiting = fundiCard(
                        color: Colors.white,
                        border: FundipapColors.blackGray,
                        icon: Icons.location_on,
                        iconColor: Colors.black,
                        title: waitingState.title,
                        message: waitingState.message,
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
                            onPressed: () =>
                                FundiTimelineActions.startSiteVisit(
                                  context,
                                  widget.jobId,
                                  widget.jobTitle,
                                ),
                          ),
                        ),
                      );
                      break;
                    case FundiWaitingType.travelling:
                      currentWaiting = fundiCard(
                        color: Colors.blue.shade50,
                        border: Colors.blue,
                        icon: Icons.directions_bike,
                        iconColor: Colors.blue,
                        title: 'You are on the way',
                        message: 'Travelling to client - open tracking',
                        time: 'Now',
                        isCurrent: true,
                        action: ElevatedButton.icon(
                          icon: const Icon(Icons.map),
                          label: const Text('OPEN TRACKING'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VisitCustomerScreen(
                                jobId: widget.jobId,
                                job: job,
                              ),
                            ),
                          ),
                        ),
                      );
                      break;
                    case FundiWaitingType.siteVisited:
                      currentWaiting = Container(
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
                              'Next action - Client locked KES $fundiSees secured to escrow',
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
                                    onPressed: () =>
                                        FundiTimelineActions.startJob(
                                          widget.jobId,
                                        ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          FundipapColors.greenSuccess,
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
                                        builder: (_) =>
                                            FundiRequestNewPriceScreen(
                                              jobId: widget.jobId,
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
                      );
                      break;
                  }
                }

                List<Widget> timeline = [];
                if (currentWaiting != null) timeline.add(currentWaiting);
                timeline.addAll(doneHistory.reversed);

                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => _goBack(2),
                    ),
                    title: Text(
                      widget.clientName,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: FundipapColors.blackGray,
                    foregroundColor: Colors.white,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
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
                                  bottom: MediaQuery.of(
                                    context,
                                  ).viewInsets.bottom,
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
                                      'Chat with ${widget.clientName}',
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
                                          jobId: widget.jobId,
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
                    itemCount: timeline.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => timeline[i],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
