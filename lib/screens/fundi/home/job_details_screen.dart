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

  int _bidPrice(Map<String, dynamic> b) =>
      _toInt(b['price'] ?? b['amount'] ?? b['bidAmount'] ?? 0);

  int _transport(Map<String, dynamic> j) => _toInt(j['transportFee'] ?? 100);

  Widget _detailRow(String label, String value) {
    if (value.isEmpty || value == 'null') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(
    String jobId,
    String bidId,
    int clientAmt,
    Map<String, dynamic> job,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final int transport = _transport(job);
    final int clientAppFee = (clientAmt * 0.05).round();
    final int fundiAppFee = (clientAmt * 0.05).round();

    await ref.collection('bids').doc(bidId).update({
      'status': 'counter_accepted_by_fundi',
      'agreedPrice': clientAmt,
      'price': clientAmt,
      'fundiAcceptedCounterAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'clientCounterSeenByFundi': true,
    });

    await ref.update({
      'status': 'counter_accepted',
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

  Widget _buildClientHeader(String clientId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .get(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: FundipapColors.blackGray,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text(
                  'Client • $clientId',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }
        var u = snap.data!.data() as Map<String, dynamic>;
        String name =
            (u['displayName'] ?? u['fullName'] ?? u['name'] ?? 'Client')
                .toString();
        String photo = (u['photoUrl'] ?? u['avatar'] ?? u['profilePhoto'] ?? '')
            .toString();
        String location = (u['location'] ?? u['address'] ?? u['estate'] ?? '')
            .toString();
        int completed = _toInt(u['completedJobs'] ?? u['jobsCompleted'] ?? 0);
        double rating =
            double.tryParse((u['rating'] ?? u['avgRating'] ?? 0).toString()) ??
            0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: FundipapColors.blackGray,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rating > 0) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.star,
                            size: 14,
                            color: FundipapColors.primaryYellow,
                          ),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Posted by • Client',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 12,
                            color: Colors.black38,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              location,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FundipapColors.greenSuccess.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed jobs',
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: FundipapColors.greenSuccess,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
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
          final String realDesc = (jData['description'] ?? jData['desc'] ?? '')
              .toString();
          final String categoryName =
              (jData['categoryName'] ??
                      jData['category'] ??
                      jData['categorySlug'] ??
                      '')
                  .toString();
          final String subcategoryName =
              (jData['subcategoryName'] ?? jData['subcategoryId'] ?? '')
                  .toString();
          final String faultName =
              (jData['faultName'] ?? jData['faultId'] ?? '').toString();
          final String serviceFilter = (jData['serviceFilter'] ?? '')
              .toString();
          final bool isInstallation = jData['isInstallation'] == true;
          final String address =
              (jData['location'] ?? jData['address'] ?? jData['area'] ?? '')
                  .toString();
          final String clientId =
              (jData['customerId'] ??
                      jData['clientId'] ??
                      jData['userId'] ??
                      '')
                  .toString();
          final photos =
              (jData['photos'] ?? jData['images'] ?? jData['photoUrls'] ?? [])
                  as List;
          final Timestamp? createdAt = jData['createdAt'] is Timestamp
              ? jData['createdAt']
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (clientId.isNotEmpty) _buildClientHeader(clientId),
                const SizedBox(height: 14),
                Text(
                  realTitle,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (categoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: FundipapColors.blackGray,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          categoryName.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (subcategoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subcategoryName,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (faultName.isNotEmpty && faultName != 'null')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          faultName,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                    if (serviceFilter.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: serviceFilter == 'install'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: serviceFilter == 'install'
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          serviceFilter.toUpperCase(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (isInstallation)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: FundipapColors.primaryYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'INSTALLATION',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (widget.distanceKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: FundipapColors.primaryYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${widget.distanceKm!.toStringAsFixed(1)} km away',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (createdAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Details',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _detailRow('Category', categoryName),
                      _detailRow('Service Type', subcategoryName),
                      if (faultName.isNotEmpty && faultName != 'null')
                        _detailRow('Specific Fault', faultName),
                      _detailRow(
                        'Job Type',
                        serviceFilter == 'install'
                            ? 'Installation'
                            : serviceFilter == 'repair'
                            ? 'Repair'
                            : 'All',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (focusedClientAmt > 0) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You bid: KES $focusedOriginal',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Client countered: KES $focusedClientAmt',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (realDesc.isNotEmpty) ...[
                  Text(
                    'Job Description',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      realDesc,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (address.isNotEmpty) ...[
                  Text(
                    'Location',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: FundipapColors.blackGray,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (photos.isNotEmpty) ...[
                  Text(
                    'Photos from client (${photos.length})',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            child: InteractiveViewer(
                              child: Image.network(photos[i].toString()),
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(photos[i].toString()),
                              fit: BoxFit.cover,
                            ),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 80),
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
                      return Container(
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
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FundipapColors.greenSuccess.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'You have placed a bid. Wait for client feedback',
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
                      'BID NOW (You set the Price)',
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
