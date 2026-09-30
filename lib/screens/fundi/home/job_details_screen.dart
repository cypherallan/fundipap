import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/animated_waiting_card.dart';
import 'fundi_bid_dialog.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final double? distanceKm;
  final Map<String, dynamic>? me;
  final int completedJobs;
  final bool hasBid;

  const JobDetailsScreen({
    super.key,
    required this.job,
    this.distanceKm,
    this.me,
    this.completedJobs = 0,
    this.hasBid = false,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  int _labour(Map<String, dynamic> j) => _toInt(
    j['laborCost'] ??
        j['agreedPrice'] ??
        j['acceptedBidAmount'] ??
        j['budget'] ??
        0,
  );
  int _transport(Map<String, dynamic> j) =>
      _toInt(j['transportFee'] ?? 100); // FIX: default 100 not 0
  int _fundiFee(int labour) => (labour * 0.05).round();
  int _bidPrice(Map<String, dynamic> b) =>
      _toInt(b['price'] ?? b['amount'] ?? b['bidAmount'] ?? 0);

  Future<void> _accept(
    String jobId,
    String bidId,
    int clientAmt,
    Map<String, dynamic> job,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final int transport = _toInt(job['transportFee'] ?? 100);
    final int clientAppFee = (clientAmt * 0.05).round();
    final int fundiAppFee = (clientAmt * 0.05).round();

    // FIX: fundi does NOT assign job, he just says "I accept your counter"
    await ref.collection('bids').doc(bidId).update({
      'status': 'counter_accepted_by_fundi', // NEW STATUS
      'agreedPrice': clientAmt,
      'price': clientAmt,
      'fundiAcceptedCounterAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'clientCounterSeenByFundi': true,
    });

    await ref.update({
      'status': 'counter_accepted', // job still open, not assigned
      'counterAcceptedBy': FieldValue.arrayUnion([uid]),
      'counterAcceptedBids': FieldValue.arrayUnion([bidId]),
      'lastCounterAcceptedBy': uid,
      'lastCounterAcceptedAt': FieldValue.serverTimestamp(),
      'transportFee': transport,
      'clientAppFee': clientAppFee,
      'fundiAppFee': fundiAppFee,
      'clientHasUnread': true,
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'toUserId': job['customerId'] ?? job['clientId'],
      'type': 'counter_accepted_by_fundi',
      'jobId': jobId,
      'bidId': bidId,
      'title': 'Fundi accepted your KES $clientAmt counter',
      'body':
          'Tap Proceed with Fundi to lock KES ${clientAmt + transport + clientAppFee} to escrow',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _reject(
    String jobId,
    String bidId,
    Map<String, dynamic> job,
    int clientAmt,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .doc(bidId)
        .update({
          'status': 'rejected',
          'rejectedBy': uid,
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'clientCounterSeenByFundi': true,
        });
  }

  Future<void> _counterDialog(
    BuildContext context,
    String jobId,
    String bidId,
    int clientAmt,
    Map<String, dynamic> jobData,
  ) async {
    final ctrl = TextEditingController(text: clientAmt.toString());
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Counter Offer',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Your counter (KES)',
            prefixText: 'KES ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmt = int.tryParse(ctrl.text.trim()) ?? 0;
              if (newAmt <= 0) return;
              Navigator.pop(ctx);
              final int transport = _transport(jobData);
              await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(jobId)
                  .collection('bids')
                  .doc(bidId)
                  .update({
                    'fundiCounterAmount': newAmt,
                    'fundiCounterPrice': newAmt,
                    'lastCounterAmount': newAmt,
                    'lastCounterPrice': newAmt,
                    'counterBy': 'fundi',
                    'lastCounterBy': uid,
                    'status': 'countered',
                    'clientHasUnread': true,
                    'fundiHasUnread': false,
                    'counterAt': FieldValue.serverTimestamp(),
                    'lastCounterAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
              await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(jobId)
                  .update({
                    'lastCounterAmount': newAmt,
                    'lastCounterPrice': newAmt,
                    'lastCounterBy': 'fundi',
                    'counterBy': 'fundi',
                    'status': 'countered',
                    'updatedAt': FieldValue.serverTimestamp(),
                    'clientHasUnread': true,
                    'transportFee': transport,
                  });
            },
            child: const Text('Send Counter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobId = (widget.job['id'] ?? widget.job['jobId'] ?? '').toString();
    final focusedBid = widget.job['focusedBid'] as Map<String, dynamic>?;
    final focusedOriginal = focusedBid != null ? _bidPrice(focusedBid) : 0;
    final focusedClientAmt = focusedBid != null
        ? _toInt(
            focusedBid['clientCounterAmount'] ??
                focusedBid['lastCounterAmount'] ??
                0,
          )
        : 0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Job Details',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .snapshots(),
        builder: (ctx, jobSnap) {
          final Map<String, dynamic> jData =
              (jobSnap.data?.data() as Map<String, dynamic>?) ?? widget.job;
          final String realTitle =
              (jData['title'] ?? jData['jobTitle'] ?? 'Job').toString();
          final String realCategory =
              (jData['category'] ?? jData['trade'] ?? '').toString();
          final photos = (jData['photos'] ?? jData['images'] ?? []) as List;
          final int labour = _labour(jData);
          final int trans = _transport(jData);
          final int rec = labour - _fundiFee(labour) + trans;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  realTitle,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (realCategory.isNotEmpty)
                      Chip(
                        label: Text(
                          realCategory.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (realCategory.isNotEmpty) const SizedBox(width: 8),
                    if (widget.distanceKm != null)
                      Chip(
                        label: Text(
                          '${widget.distanceKm!.toStringAsFixed(1)} km away',
                          style: GoogleFonts.inter(fontSize: 10),
                        ),
                        backgroundColor: FundipapColors.primaryYellow,
                      ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (focusedClientAmt > 0) ...[
                          Text(
                            'You bid: KES $focusedOriginal',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Client countered: KES $focusedClientAmt',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ] else ...[
                          Text(
                            'KES ${jData['budget'] ?? ''} OFFERED',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (labour > 0)
                            Text(
                              'You receive: KES $rec',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: Colors.green.shade700,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (photos.isNotEmpty) ...[
                  Text(
                    'Photos from client',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      itemBuilder: (_, i) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(photos[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.of(context).viewPadding.bottom + 12,
          ),
          color: Colors.white,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .snapshots(),
            builder: (ctx, jobSnap) {
              var jData =
                  (jobSnap.data?.data() as Map<String, dynamic>?) ?? widget.job;
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .collection('bids')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .snapshots(),
                builder: (ctx2, bidSnap) {
                  var bidData = bidSnap.data?.data() as Map<String, dynamic>?;
                  bool alreadyBid =
                      widget.hasBid ||
                      (bidSnap.hasData && bidSnap.data!.exists);
                  if (bidData != null) {
                    String bStatus = (bidData['status'] ?? '').toString();
                    String lastBy =
                        (bidData['lastCounterBy'] ?? bidData['counterBy'] ?? '')
                            .toString();
                    int clientAmt = _toInt(
                      bidData['clientCounterAmount'] ??
                          bidData['lastCounterAmount'] ??
                          bidData['agreedPrice'] ??
                          0,
                    );
                    int originalPrice = _bidPrice(bidData);
                    int myCounterAmt = _toInt(
                      bidData['fundiCounterAmount'] ?? 0,
                    );

                    bool isClientCounter =
                        (bStatus == 'countered' &&
                            lastBy != FirebaseAuth.instance.currentUser!.uid) ||
                        bStatus == 'client_counter';
                    bool isMyCounter =
                        bStatus == 'countered' &&
                        lastBy == FirebaseAuth.instance.currentUser!.uid;
                    bool isCounterAccepted =
                        bStatus == 'counter_accepted_by_fundi';

                    if (isCounterAccepted) {
                      // NEW - This fixes the full-screen issue - compact card in bottom nav, not full page
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.blue.shade700,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Accepted counter KES $clientAmt - Waiting for client to confirm',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    if (isClientCounter) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.compare_arrows,
                                  color: Colors.orange.shade800,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Client countered your KES $originalPrice with KES $clientAmt',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _reject(
                                    jobId,
                                    bidSnap.data!.id,
                                    jData,
                                    clientAmt,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _counterDialog(
                                    context,
                                    jobId,
                                    bidSnap.data!.id,
                                    clientAmt,
                                    jData,
                                  ),
                                  child: const Text('Counter'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        FundipapColors.greenSuccess,
                                  ),
                                  onPressed: () => _accept(
                                    jobId,
                                    bidSnap.data!.id,
                                    clientAmt,
                                    jData,
                                  ),
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    if (isMyCounter) {
                      return OrangeAnimatedWaitingCard(
                        title: 'Counter sent • KES $myCounterAmt',
                        message:
                            'You countered KES $myCounterAmt. Waiting for client...',
                      );
                    }
                  }
                  if (alreadyBid) {
                    final int labour = _labour(jData);
                    final int trans = _transport(jData);
                    final int rec = labour - _fundiFee(labour) + trans;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FundipapColors.greenSuccess.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'You have placed a bid. Wait for client feedback - You will receive KES $rec if accepted',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: FundipapColors.greenSuccess,
                        ),
                      ),
                    );
                  }
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.blackGray,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) =>
                          FundiBidDialog(jobId: jobId, jobData: jData),
                    ),
                    child: Text(
                      'BID NOW',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
