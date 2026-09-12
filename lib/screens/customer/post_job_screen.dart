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

  Future<void> _handleCounterBid(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
    double currentPrice,
  ) async {
    try {
      String? bidId = job['acceptedBidId']?.toString();
      DocumentReference bidRef;
      if (bidId != null && bidId.isNotEmpty) {
        bidRef = FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .collection('bids')
            .doc(bidId);
      } else {
        final assignedFundi = job['assignedFundi'];
        if (assignedFundi == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No assigned fundi')));
          return;
        }
        final q = await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .collection('bids')
            .where('fundiId', isEqualTo: assignedFundi)
            .limit(1)
            .get();
        if (q.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bid not found for counter')),
          );
          return;
        }
        bidRef = q.docs.first.reference;
      }
      await _counterBid(context, bidRef, jobId, currentPrice);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Counter error: $e')));
    }
  }

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
              decoration: const InputDecoration(labelText: 'Your counter KES'),
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
      'byName': userDoc.data()?['username'] ?? 'Client',
      'message': msgCtrl.text.trim(),
      'at': FieldValue.serverTimestamp(),
    });
    await bidRef.update({
      'status': 'countered',
      'lastCounterPrice': newPrice,
      'lastCounterBy': uid,
      'lastCounterAt': FieldValue.serverTimestamp(),
    });

    // Update job - IMPORTANT: client cannot confirm his own counter, fundi must
    var jobSnap = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
    var hasReneg = (jobSnap.data()?['renegotiation']?['requested'] == true);

    if (hasReneg) {
      // This is a renegotiation counter
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'negotiating',
        'renegotiation.status': 'countered_by_client',
        'renegotiation.newPrice': newPrice,
        'renegotiation.reason': msgCtrl.text.trim(),
        'renegotiation.lastCounterBy': uid,
        'renegotiation.lastCounterAt': FieldValue.serverTimestamp(),
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_client',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // This is initial bidding counter
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'negotiating',
        'renegotiation': {'requested': false},
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_client',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
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
      'acceptedBidId': bidRef.id,
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
    var otherBids = await jobRef
        .collection('bids')
        .where('status', whereIn: ['pending', 'countered', 'bidding'])
        .get();
    for (var b in otherBids.docs) {
      if (b.id != bidRef.id) {
        await b.reference.update({
          'status': 'rejected',
          'rejectionCategory': 'Another offer accepted',
        });
      }
    }
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
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'escrowStatus': 'held',
        'escrowAmount': amount,
        'escrowHeldAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KES ${amount.toInt()} held in escrow (simulated)'),
            backgroundColor: FundipapColors.greenSuccess,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText('Error: ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
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
    var uid = FirebaseAuth.instance.currentUser!.uid;
    if (jobs.isEmpty) {
      return Center(child: Text('No pending jobs', style: GoogleFonts.inter()));
    }
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
                    if (!bidSnap.hasData) {
                      return const LinearProgressIndicator();
                    }
                    var bids = bidSnap.data!.docs;
                    if (bids.isEmpty) {
                      return Text(
                        'No bids yet',
                        style: GoogleFonts.inter(fontSize: 11),
                      );
                    }
                    return Column(
                      children: bids.map((b) {
                        var bid = b.data() as Map<String, dynamic>;
                        if (bid['status'] == 'rejected') {
                          return const SizedBox.shrink();
                        }
                        bool isMyCounter = bid['lastCounterBy'] == uid;
                        bool isCounteredByMe =
                            bid['status'] == 'countered' && isMyCounter;
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
                              if (isCounteredByMe) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'You countered KES ${bid['lastCounterPrice']}. Waiting for fundi to accept...',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const LinearProgressIndicator(),
                              ] else ...[
                                const SizedBox(height: 6),
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
    if (docs.isEmpty) {
      return Center(
        child: Text('No confirmed jobs', style: GoogleFonts.inter()),
      );
    }
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
        bool showRenegCard =
            reneg != null &&
            reneg['requested'] == true &&
            reneg['status'] != 'accepted';
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
                if (showRenegCard)
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
                          reneg['status'] == 'countered_by_client'
                              ? 'You countered'
                              : 'Fundi requests new price after site visit',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New: KES ${reneg['newPrice']} Reason: ${reneg['reason']}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        if (reneg['status'] == 'pending' ||
                            reneg['status'] == 'countered_by_fundi')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async =>
                                      await _acceptRenegotiation(
                                        jobId,
                                        reneg,
                                        agreed,
                                      ),
                                  child: const Text('Accept New Price'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _handleCounterBid(
                                    context,
                                    jobId,
                                    job,
                                    (reneg['newPrice'] as num).toDouble(),
                                  ),
                                  child: const Text('Counter'),
                                ),
                              ),
                            ],
                          )
                        else if (reneg['status'] == 'countered_by_client')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Waiting for fundi to accept your KES ${reneg['newPrice']}...',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const LinearProgressIndicator(),
                            ],
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (escrow == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _payEscrowSimulated(
                        context,
                        jobId,
                        agreed.toDouble(),
                      ),
                      child: Text(
                        'Pay KES $agreed to Escrow (Mpesa Simulated)',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ),
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
            if (!bidSnap.hasData || bidSnap.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
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
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No completed jobs yet',
          style: GoogleFonts.inter(color: Colors.black45),
        ),
      );
    }
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
