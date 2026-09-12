import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FundiMyJobsPage extends StatefulWidget {
  const FundiMyJobsPage({super.key});
  @override
  State<FundiMyJobsPage> createState() => _FundiMyJobsPageState();
}

class _FundiMyJobsPageState extends State<FundiMyJobsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  Future<void> _counterAsFundi(
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
              decoration: const InputDecoration(
                labelText: 'New price KES (include parts)',
              ),
            ),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(
                labelText: 'Include part costs breakdown',
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
      'lastCounterBy': uid,
    });
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'negotiating',
      'priceHistory': FieldValue.arrayUnion([
        {
          'price': newPrice,
          'by': uid,
          'type': 'counter',
          'at': DateTime.now().toIso8601String(),
        },
      ]),
    });
  }

  Future<void> _requestNewPriceAfterVisit(String jobId) async {
    final priceCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Request New Price After Site Visit',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New total price KES (labor+parts)',
              ),
            ),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Why more? Describe site findings + parts needed',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload photos in real app - simulated for now',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
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
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (res != true) return;
    double newPrice = double.tryParse(priceCtrl.text) ?? 0;
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation': {
        'requested': true,
        'newPrice': newPrice,
        'reason': reasonCtrl.text.trim(),
        'status': 'pending',
        'requestedBy': FirebaseAuth.instance.currentUser!.uid,
        'at': FieldValue.serverTimestamp(),
      },
      'siteVisitDone': true,
      'siteVisitFindings': reasonCtrl.text.trim(),
      'status': 'site_visit',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _startJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addParts(String jobId) async {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Part Cost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Part name'),
            ),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cost KES'),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != true) return;
    double cost = double.tryParse(costCtrl.text) ?? 0;
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'parts': FieldValue.arrayUnion([
        {
          'name': nameCtrl.text,
          'cost': cost,
          'at': DateTime.now().toIso8601String(),
        },
      ]),
    });
  }

  Future<void> _markCompletedFundi(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'fundiConfirmedComplete': true,
      'status': 'pending_completion',
      'fundiCompletedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var jobsStream = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundi', isEqualTo: uid)
        .snapshots();
    var bidsStream = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          'My Jobs',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          tabs: const [
            Tab(text: 'PENDING'),
            Tab(text: 'CONFIRMED'),
            Tab(text: 'REJECTED'),
            Tab(text: 'COMPLETED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // PENDING
          StreamBuilder<QuerySnapshot>(
            stream: bidsStream,
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(child: SelectableText('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var filtered = snap.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return (data['status'] == 'pending' ||
                        data['status'] == 'countered' ||
                        data['status'] == 'bidding') &&
                    data['deletedForFundi'] != true;
              }).toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No pending offers',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  var bid = filtered[i].data() as Map<String, dynamic>;
                  var jobRef = filtered[i].reference.parent.parent;
                  return FutureBuilder<DocumentSnapshot>(
                    future: jobRef!.get(),
                    builder: (_, jobSnap) {
                      var job = jobSnap.data?.data() as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PENDING • KES ${bid['lastCounterPrice'] ?? bid['price']}',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            Text(
                              job?['title'] ?? 'Job',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              job?['location'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (bid['status'] == 'countered' &&
                                bid['lastCounterBy'] != uid)
                              Text(
                                'Client countered: KES ${bid['lastCounterPrice']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _counterAsFundi(
                                      filtered[i].reference,
                                      jobRef.id,
                                      (bid['lastCounterPrice'] ?? bid['price'])
                                          .toDouble(),
                                    ),
                                    child: const Text('Counter'),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                    ),
                                    child: const Text('Waiting Client'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          // CONFIRMED
          StreamBuilder<QuerySnapshot>(
            stream: jobsStream,
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(child: SelectableText('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data!.docs
                  .where(
                    (d) => [
                      'assigned',
                      'site_visit',
                      'in_progress',
                      'pending_completion',
                    ].contains((d.data() as Map)['status']),
                  )
                  .toList();
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No confirmed jobs',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  var job = docs[i].data() as Map<String, dynamic>;
                  var jobId = docs[i].id;
                  String escrow = job['escrowStatus'] ?? 'pending';
                  bool siteDone = job['siteVisitDone'] ?? false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FundipapColors.greenSuccess),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${job['status'].toString().toUpperCase()} • KES ${job['agreedPrice'] ?? job['budget']}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          job['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Client: ${job['customerName'] ?? job['clientName'] ?? 'Client'} • Escrow: $escrow',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        if (escrow != 'held')
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Waiting for client to pay to escrow (Mpesa simulated). You cannot start until held.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        if (escrow == 'held' && !siteDone)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(jobId)
                                      .update({
                                        'siteVisitDone': true,
                                        'siteVisitAt':
                                            FieldValue.serverTimestamp(),
                                      }),
                                  child: const Text('Mark Site Visited'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      _requestNewPriceAfterVisit(jobId),
                                  child: const Text('Request New Price'),
                                ),
                              ),
                            ],
                          ),
                        if (escrow == 'held' && job['status'] == 'assigned')
                          ElevatedButton(
                            onPressed: () => _startJob(jobId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FundipapColors.greenSuccess,
                            ),
                            child: const Text(
                              'START JOB',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        if (job['status'] == 'in_progress')
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _addParts(jobId),
                                  child: const Text('Add Part Receipt'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _markCompletedFundi(jobId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        FundipapColors.primaryYellow,
                                  ),
                                  child: const Text('Mark Completed'),
                                ),
                              ),
                            ],
                          ),
                        if (job['status'] == 'pending_completion')
                          Text(
                            'Waiting for client to confirm completion to release KES ${job['agreedPrice']}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // REJECTED
          StreamBuilder<QuerySnapshot>(
            stream: bidsStream,
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(child: SelectableText('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var filtered = snap.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['status'] == 'rejected' &&
                    data['deletedForFundi'] != true;
              }).toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No rejected offers',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  var bid = filtered[i].data() as Map<String, dynamic>;
                  var jobRef = filtered[i].reference.parent.parent;
                  return FutureBuilder<DocumentSnapshot>(
                    future: jobRef!.get(),
                    builder: (_, jobSnap) {
                      var job = jobSnap.data?.data() as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: FundipapColors.redAlert),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'REJECTED • KES ${bid['price']}',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: FundipapColors.redAlert,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 16),
                                  onPressed: () async {
                                    await filtered[i].reference.update({
                                      'deletedForFundi': true,
                                    });
                                  },
                                ),
                              ],
                            ),
                            Text(
                              job?['title'] ?? 'Job',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Reason: ${bid['rejectionCategory'] ?? ''} ${bid['rejectionReason'] ?? ''}',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          // COMPLETED
          StreamBuilder<QuerySnapshot>(
            stream: jobsStream,
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(child: SelectableText('Error: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data!.docs
                  .where((d) => (d.data() as Map)['status'] == 'completed')
                  .toList();
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No completed jobs',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  var job = docs[i].data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COMPLETED • KES ${job['agreedPrice'] ?? job['budget']}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          job['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
