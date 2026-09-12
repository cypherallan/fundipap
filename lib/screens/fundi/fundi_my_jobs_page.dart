import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      'lastCounterAt': FieldValue.serverTimestamp(),
    });

    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var jobSnap = await jobRef.get();
    var jobStatus = jobSnap.data()?['status'] ?? '';

    if (['assigned', 'site_visit', 'negotiating'].contains(jobStatus)) {
      // renegotiation counter - fundi counters client, now client must confirm
      await jobRef.update({
        'status': 'negotiating',
        'renegotiation.status': 'countered_by_fundi',
        'renegotiation.newPrice': newPrice,
        'renegotiation.reason': msgCtrl.text.trim(),
        'renegotiation.lastCounterBy': uid,
        'renegotiation.lastCounterAt': FieldValue.serverTimestamp(),
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_fundi',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // initial bidding counter
      await jobRef.update({
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
      });
    }
  }

  Future<void> _markSiteVisited(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'siteVisitDone': true,
      'siteVisitAt': FieldValue.serverTimestamp(),
      'status': 'site_visit',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _requestNewPriceAfterVisit(String jobId) async {
    final priceCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final picker = ImagePicker();
    List<XFile> pickedImages = [];
    bool isUploading = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            'Request New Price After Site Visit',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New total price KES (labor+parts)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'Why more? Describe site findings + parts needed',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Site Photos (optional for now)',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (pickedImages.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pickedImages
                        .map(
                          (x) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(x.path),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      setDialog(() => pickedImages.remove(x)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(
                    pickedImages.isEmpty
                        ? 'Add Photos (Optional)'
                        : 'Add More Photos',
                  ),
                  onPressed: () async {
                    final imgs = await picker.pickMultiImage(imageQuality: 70);
                    if (imgs.isNotEmpty)
                      setDialog(() => pickedImages.addAll(imgs));
                  },
                ),
                if (isUploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  SizedBox(height: 4),
                  Text(
                    pickedImages.isEmpty
                        ? 'Sending...'
                        : 'Uploading ${pickedImages.length} photos...',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (priceCtrl.text.trim().isEmpty ||
                          reasonCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Price and reason required'),
                          ),
                        );
                        return;
                      }
                      setDialog(() => isUploading = true);
                      List<String> urls = [];
                      try {
                        if (pickedImages.isNotEmpty) {
                          for (var f in pickedImages) {
                            final ref = FirebaseStorage.instance.ref().child(
                              'jobs/$jobId/siteVisit/${DateTime.now().millisecondsSinceEpoch}_${f.name}',
                            );
                            await ref.putFile(File(f.path));
                            urls.add(await ref.getDownloadURL());
                          }
                        }
                        Navigator.pop(ctx, {
                          'price': priceCtrl.text.trim(),
                          'reason': reasonCtrl.text.trim(),
                          'photos': urls,
                        });
                      } catch (e) {
                        setDialog(() => isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Upload failed, sending without photos: $e',
                            ),
                          ),
                        );
                        // fallback - send without photos if storage fails (free plan)
                        Navigator.pop(ctx, {
                          'price': priceCtrl.text.trim(),
                          'reason': reasonCtrl.text.trim(),
                          'photos': [],
                        });
                      }
                    },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    double newPrice = double.tryParse(result['price']) ?? 0;
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation': {
        'requested': true,
        'newPrice': newPrice,
        'reason': result['reason'],
        'photos': result['photos'],
        'status': 'pending',
        'requestedBy': FirebaseAuth.instance.currentUser!.uid,
        'at': FieldValue.serverTimestamp(),
      },
      'siteVisitDone': true,
      'siteVisitFindings': result['reason'],
      'siteVisitPhotos': result['photos'],
      'siteVisitAt': FieldValue.serverTimestamp(),
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
                            const SizedBox(height: 8),
                            if (bid['status'] == 'countered' &&
                                bid['lastCounterBy'] != uid) ...[
                              Text(
                                'Client countered: KES ${bid['lastCounterPrice']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _counterAsFundi(
                                        filtered[i].reference,
                                        jobRef.id,
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
                                      onPressed: () async {
                                        // fundi accepts client counter
                                        await filtered[i].reference.update({
                                          'status': 'pending_client_accept',
                                        });
                                        await FirebaseFirestore.instance
                                            .collection('jobs')
                                            .doc(jobRef.id)
                                            .update({
                                              'renegotiation': {
                                                'requested': false,
                                              },
                                              'priceHistory': FieldValue.arrayUnion([
                                                {
                                                  'price':
                                                      bid['lastCounterPrice'],
                                                  'by': uid,
                                                  'type':
                                                      'accepted_client_counter',
                                                  'at': DateTime.now()
                                                      .toIso8601String(),
                                                },
                                              ]),
                                            });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Accepted client KES ${bid['lastCounterPrice']} - waiting client to confirm job',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Accept',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (bid['lastCounterBy'] == uid) ...[
                              Text(
                                'You countered KES ${bid['lastCounterPrice']}. Waiting for client...',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const LinearProgressIndicator(),
                            ] else ...[
                              Text(
                                'Waiting for client to accept your KES ${bid['price']}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          // CONFIRMED - FIXED
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
                  var reneg = job['renegotiation'] as Map<String, dynamic>?;

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
                        if (escrow == 'held') ...[
                          if (!siteDone) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _markSiteVisited(jobId),
                                    child: const Text(
                                      'Mark Site Visited',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () =>
                                        _requestNewPriceAfterVisit(jobId),
                                    child: const Text(
                                      'Request New Price',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              onPressed: () => _startJob(jobId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FundipapColors.greenSuccess,
                              ),
                              child: const Text(
                                'START JOB WITHOUT NEW PRICE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                          if (siteDone) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✓ Site visited. Client notified. Status: ${job['status']}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (reneg != null &&
                                reneg['requested'] == true &&
                                reneg['status'] != 'accepted') ...[
                              if (reneg['status'] == 'countered_by_client')
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Client countered: KES ${reneg['newPrice']}',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'Reason: ${reneg['reason'] ?? ''}',
                                        style: GoogleFonts.inter(fontSize: 11),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () async {
                                                await FirebaseFirestore.instance
                                                    .collection('jobs')
                                                    .doc(jobId)
                                                    .update({
                                                      'agreedPrice':
                                                          reneg['newPrice'],
                                                      'totalCost':
                                                          reneg['newPrice'],
                                                      'escrowAmount':
                                                          reneg['newPrice'],
                                                      'renegotiation': {
                                                        'requested': false,
                                                        'status': 'accepted',
                                                      },
                                                      'status': 'site_visit',
                                                    });
                                              },
                                              child: const Text(
                                                'Accept Client Price',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _requestNewPriceAfterVisit(
                                                    jobId,
                                                  ),
                                              child: const Text('Counter'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'You asked KES ${reneg['newPrice']}. Waiting client...',
                                        style: GoogleFonts.inter(fontSize: 11),
                                      ),
                                      const SizedBox(height: 4),
                                      const LinearProgressIndicator(),
                                    ],
                                  ),
                                ),
                            ] else if (job['status'] == 'assigned' ||
                                job['status'] == 'site_visit')
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _startJob(jobId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            FundipapColors.greenSuccess,
                                      ),
                                      child: const Text(
                                        'START JOB',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _requestNewPriceAfterVisit(jobId),
                                      child: const Text('Request New Price'),
                                    ),
                                  ),
                                ],
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
                                      onPressed: () =>
                                          _markCompletedFundi(jobId),
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
                        ],
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
