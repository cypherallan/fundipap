import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'post_new_job_screen.dart';

class PostJobScreen extends StatelessWidget {
  const PostJobScreen({super.key});

  Future<void> _deleteJob(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Delete Job?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove it completely.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.redAlert,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    var bids = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .get();
    for (var b in bids.docs) {
      await b.reference.delete();
    }
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
  }

  Future<void> _editJob(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostNewJobScreen(jobId: jobId, existingJob: job),
      ),
    );
  }

  // NEGOTIATION: Counter bid
  Future<void> _counterBid(
    BuildContext context,
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
              decoration: const InputDecoration(labelText: 'Your price KES'),
            ),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
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
      'byName': userDoc.data()?['username'] ?? 'Client',
      'message': msgCtrl.text.trim(),
      'at': FieldValue.serverTimestamp(),
    });
    await bidRef.update({
      'status': 'countered',
      'lastCounterPrice': newPrice,
      'lastCounterBy': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'negotiating',
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': newPrice,
          'by': uid,
          'at': DateTime.now().toIso8601String(),
          'type': 'counter',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _acceptBid(
    BuildContext context,
    DocumentReference bidRef,
    String jobId,
    Map<String, dynamic> bidData,
  ) async {
    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var jobSnap = await jobRef.get();
    var jobData = jobSnap.data() ?? {};
    double finalPrice =
        (bidData['lastCounterPrice'] ??
                bidData['price'] ??
                jobData['budget'] ??
                0)
            .toDouble();
    await jobRef.update({
      'assignedFundi': bidData['fundiId'],
      'assignedFundiName': bidData['fundiName'],
      'assignedFundiPhone': bidData['fundiPhone'] ?? '',
      'agreedPrice': finalPrice,
      'laborCost': finalPrice,
      'totalCost': finalPrice,
      'status': 'assigned',
      'escrowStatus': 'pending',
      'escrowAmount': finalPrice,
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': finalPrice,
          'by': FirebaseAuth.instance.currentUser!.uid,
          'at': DateTime.now().toIso8601String(),
          'type': 'accepted',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await bidRef.update({'status': 'accepted'});
    // reject others client side
    var otherBids = await jobRef
        .collection('bids')
        .where('status', whereIn: ['pending', 'countered', 'bidding'])
        .get();
    for (var b in otherBids.docs) {
      if (b.id != bidRef.id)
        await b.reference.update({
          'status': 'rejected',
          'rejectionCategory': 'Another offer accepted',
        });
    }
    // create escrow tx simulated
    await FirebaseFirestore.instance
        .collection('escrowTransactions')
        .doc(jobId)
        .set({
          'jobId': jobId,
          'clientId': FirebaseAuth.instance.currentUser!.uid,
          'fundiId': bidData['fundiId'],
          'amount': finalPrice,
          'status': 'pending_payment',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _payEscrowSimulated(
    BuildContext context,
    String jobId,
    double amount,
  ) async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    String phone = userDoc.data()?['phone'] ?? 'your Mpesa number';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Mpesa Payment - SIMULATED',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Simulating STK Push to $phone for KES $amount\n\nWhen you get Daraja keys, this will call your Cloud Function.',
          style: GoogleFonts.inter(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay Now (Simulate)'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await Future.delayed(const Duration(seconds: 2));
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'status': 'site_visit',
      'escrowPaidAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .collection('escrowTransactions')
        .doc(jobId)
        .update({'status': 'held', 'paidAt': FieldValue.serverTimestamp()});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment held in escrow: KES $amount - Fundi can now start',
        ),
      ),
    );
  }

  Future<void> _acceptRenegotiation(
    String jobId,
    Map<String, dynamic> renegotiation,
    double oldPrice,
  ) async {
    double newPrice = (renegotiation['newPrice'] ?? oldPrice).toDouble();
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'agreedPrice': newPrice,
      'totalCost': newPrice,
      'escrowAmount': newPrice,
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': newPrice,
          'by': 'fundi',
          'reason': renegotiation['reason'],
          'at': DateTime.now().toIso8601String(),
          'type': 'renegotiated',
        },
      ]),
      'renegotiation': {'requested': false, 'status': 'accepted'},
      'status': 'site_visit',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // if new price > old, create topup requirement
    if (newPrice > oldPrice) {
      await FirebaseFirestore.instance
          .collection('escrowTransactions')
          .doc(jobId)
          .update({
            'amount': newPrice,
            'topUpRequired': newPrice - oldPrice,
            'status': 'topup_pending',
          });
    }
  }

  Future<void> _confirmCompletionClient(String jobId) async {
    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var snap = await jobRef.get();
    bool fundiDone = (snap.data()?['fundiConfirmedComplete'] ?? false);
    await jobRef.update({
      'clientConfirmedComplete': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (fundiDone) {
      await jobRef.update({
        'status': 'completed',
        'escrowStatus': 'released',
        'completedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('escrowTransactions')
          .doc(jobId)
          .update({
            'status': 'released',
            'releasedAt': FieldValue.serverTimestamp(),
          });
    } else {
      await jobRef.update({'status': 'pending_completion'});
    }
  }

  Future<void> _showClientRateFundiDialog(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Rate ${job['assignedFundiName'] ?? 'Fundi'}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      Icons.star,
                      color: i < rating ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => setSt(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: 'Feedback'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                var fundiId = job['assignedFundi'];
                var uid = FirebaseAuth.instance.currentUser!.uid;
                var userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
                await FirebaseFirestore.instance
                    .collection('fundis')
                    .doc(fundiId)
                    .collection('reviews')
                    .add({
                      'clientId': uid,
                      'clientName': userDoc.data()?['username'] ?? 'Client',
                      'rating': rating,
                      'comment': commentCtrl.text.trim(),
                      'jobId': jobId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                var fundiDoc = await FirebaseFirestore.instance
                    .collection('fundis')
                    .doc(fundiId)
                    .get();
                var oldCount = (fundiDoc.data()?['ratingCount'] ?? 0) as int;
                var oldAvg = (fundiDoc.data()?['averageRating'] ?? 4.5)
                    .toDouble();
                var newAvg = ((oldAvg * oldCount) + rating) / (oldCount + 1);
                await FirebaseFirestore.instance
                    .collection('fundis')
                    .doc(fundiId)
                    .update({
                      'jobsCompleted': FieldValue.increment(1),
                      'ratingCount': FieldValue.increment(1),
                      'averageRating': newAvg,
                      'rating': newAvg,
                    });
                await FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .update({'clientRated': true});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thanks! Fundi rated')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelColor: Colors.black,
              indicatorColor: FundipapColors.primaryYellow,
              labelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Rejected'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostNewJobScreen()),
                ),
                icon: const Icon(Icons.add, color: Colors.black),
                label: Text(
                  'Post New Job',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.hasError)
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText('Error: ${snap.error}'),
                    ),
                  );
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                var allDocs = snap.data!.docs;
                return TabBarView(
                  children: [
                    _buildPendingWithBids(
                      allDocs
                          .where(
                            (d) => [
                              'open',
                              'bidding',
                              'negotiating',
                            ].contains((d.data() as Map)['status']),
                          )
                          .toList(),
                      context,
                    ),
                    _buildConfirmedClient(
                      allDocs
                          .where(
                            (d) => [
                              'assigned',
                              'site_visit',
                              'in_progress',
                              'pending_completion',
                            ].contains((d.data() as Map)['status']),
                          )
                          .toList(),
                      context,
                    ),
                    _buildRejectedList(allDocs),
                    _buildCompletedList(
                      allDocs
                          .where(
                            (d) => (d.data() as Map)['status'] == 'completed',
                          )
                          .toList(),
                      context,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingWithBids(
    List<QueryDocumentSnapshot> jobs,
    BuildContext context,
  ) {
    if (jobs.isEmpty)
      return Center(child: Text('No pending jobs', style: GoogleFonts.inter()));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: jobs.length,
      itemBuilder: (_, i) {
        var jobDoc = jobs[i];
        var job = jobDoc.data() as Map<String, dynamic>;
        var jobId = jobDoc.id;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Budget KES ${job['budget']} • ${job['status']}',
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(jobId)
                      .collection('bids')
                      .snapshots(),
                  builder: (_, bidSnap) {
                    if (!bidSnap.hasData)
                      return const LinearProgressIndicator();
                    var bids = bidSnap.data!.docs;
                    if (bids.isEmpty)
                      return Text(
                        'No bids yet',
                        style: GoogleFonts.inter(fontSize: 11),
                      );
                    return Column(
                      children: bids.map((b) {
                        var bid = b.data() as Map<String, dynamic>;
                        if (bid['status'] == 'rejected')
                          return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${bid['fundiName'] ?? 'Fundi'} • KES ${bid['lastCounterPrice'] ?? bid['price']}',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (bid['message'] != null)
                                Text(
                                  bid['message'],
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _counterBid(
                                        context,
                                        b.reference,
                                        jobId,
                                        (bid['lastCounterPrice'] ??
                                                bid['price'])
                                            .toDouble(),
                                      ),
                                      child: const Text('Counter'),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            FundipapColors.greenSuccess,
                                      ),
                                      onPressed: () => _acceptBid(
                                        context,
                                        b.reference,
                                        jobId,
                                        bid,
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
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editJob(context, jobId, job),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.redAlert,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _deleteJob(context, jobId),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmedClient(
    List<QueryDocumentSnapshot> docs,
    BuildContext context,
  ) {
    if (docs.isEmpty)
      return Center(
        child: Text('No confirmed jobs', style: GoogleFonts.inter()),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var doc = docs[i];
        var job = doc.data() as Map<String, dynamic>;
        var jobId = doc.id;
        double agreed = (job['agreedPrice'] ?? job['budget'] ?? 0).toDouble();
        String escrow = job['escrowStatus'] ?? 'pending';
        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        bool hasReneg =
            reneg != null &&
            reneg['requested'] == true &&
            reneg['status'] == 'pending';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['title'] ?? '',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Agreed: KES $agreed • Escrow: $escrow • ${job['status']}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                if (hasReneg)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fundi requests new price after site visit',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'New: KES ${reneg['newPrice']} Reason: ${reneg['reason']}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _acceptRenegotiation(
                                    jobId,
                                    reneg,
                                    agreed,
                                  );
                                },
                                child: const Text('Accept New Price'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _counterBid(
                                  context,
                                  FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(jobId)
                                      .collection('bids')
                                      .doc(job['acceptedBidId'] ?? ''),
                                  jobId,
                                  (reneg['newPrice']).toDouble(),
                                ),
                                child: const Text('Counter'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (escrow == 'pending')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.primaryYellow,
                    ),
                    onPressed: () =>
                        _payEscrowSimulated(context, jobId, agreed),
                    child: Text('Pay KES $agreed to Escrow (Mpesa Simulated)'),
                  ),
                if (job['status'] == 'pending_completion')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.greenSuccess,
                    ),
                    onPressed: () => _confirmCompletionClient(jobId),
                    child: const Text(
                      'Confirm Completion & Release Payment',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (job['status'] == 'in_progress')
                  Text(
                    'Fundi is working... parts: ${(job['parts'] ?? []).length} items',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.blue),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRejectedList(List<QueryDocumentSnapshot> allJobDocs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allJobDocs.length,
      itemBuilder: (_, i) {
        var jobId = allJobDocs[i].id;
        var jobData = allJobDocs[i].data() as Map<String, dynamic>;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .collection('bids')
              .where('status', isEqualTo: 'rejected')
              .snapshots(),
          builder: (_, bidSnap) {
            if (!bidSnap.hasData || bidSnap.data!.docs.isEmpty)
              return const SizedBox.shrink();
            var bids = bidSnap.data!.docs
                .where((b) => (b.data() as Map)['deletedForClient'] != true)
                .toList();
            if (bids.isEmpty) return const SizedBox.shrink();
            return Column(
              children: bids.map((bidDoc) {
                var bid = bidDoc.data() as Map<String, dynamic>;
                return Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    title: Text(
                      '${jobData['title']}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      'Fundi: ${bid['fundiName'] ?? 'Fundi'} • KES ${bid['price']}\n${bid['rejectionReason'] ?? ''}',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      onPressed: () async {
                        await bidDoc.reference.update({
                          'deletedForClient': true,
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedList(
    List<QueryDocumentSnapshot> docs,
    BuildContext context,
  ) {
    if (docs.isEmpty)
      return Center(
        child: Text(
          'No completed jobs yet',
          style: GoogleFonts.inter(color: Colors.black45),
        ),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var d = docs[i].data() as Map<String, dynamic>;
        var jobId = docs[i].id;
        bool alreadyRated = d['clientRated'] == true;
        return Card(
          child: ListTile(
            title: Text(d['title'] ?? ''),
            subtitle: Text(
              'KES ${d['agreedPrice'] ?? d['budget']} • ${d['assignedFundiName'] ?? 'Fundi'}',
            ),
            trailing: alreadyRated
                ? const Icon(Icons.check_circle, color: Colors.green)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.primaryYellow,
                    ),
                    onPressed: () =>
                        _showClientRateFundiDialog(context, jobId, d),
                    child: Text(
                      'Rate',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
