import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'bid_dialog.dart';
import '../client_profile_screen.dart';

class JobDetailsScreen extends StatelessWidget {
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

  int _labour(Map<String, dynamic> j) =>
      (j['agreedPrice'] ??
              j['laborCost'] ??
              j['budget'] ??
              j['offeredPrice'] ??
              0 as num)
          .toInt();
  int _transport(Map<String, dynamic> j) =>
      (j['transportFee'] ?? 0 as num).toInt();
  int _fundiFee(int labour) => (labour * 0.05).round();
  int _clientFee(int labour) => (labour * 0.05).round();

  @override
  Widget build(BuildContext context) {
    final photos = (job['photos'] ?? job['images'] ?? []) as List;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final jobId = job['id'] ?? job['jobId'];
    final labour = _labour(job);
    final trans = _transport(job);
    final fFee = _fundiFee(labour);
    final cFee = _clientFee(labour);
    final fundiReceives = labour - fFee + trans; // 4850
    final clientLocks = labour + trans + cFee; // 5350
    final fundiSeesWaiting = labour + trans; // 5100 - hide 5%+5%

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Job Details',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
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
                  (jobSnap.data?.data() as Map<String, dynamic>?) ?? job;
              bool isAssignedToMe =
                  jData['assignedFundi'] == uid ||
                  jData['assignedFundiId'] == uid;
              String status = jData['status'] ?? 'open';

              // STATE 2: Assigned - waiting for client to lock
              if (isAssignedToMe &&
                  (status == 'assigned' ||
                      jData['escrowStatus'] == 'pending')) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Waiting for client to lock',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'KES $fundiSeesWaiting',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Labour + Transport (App fee deducted on payout)',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // STATE 3: Completed - show what fundi actually receives
              if (isAssignedToMe &&
                  (status == 'completed' || status == 'site_visit')) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout Breakdown',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      _row('Labour cost:', 'KES $labour'),
                      _row('Transport:', '+ KES $trans'),
                      _row('App maintenance cost:', '- KES $fFee'),
                      Divider(),
                      _row(
                        'Total to receive:',
                        'KES $fundiReceives',
                        bold: true,
                      ),
                    ],
                  ),
                );
              }

              // STATE 1: Open - bidding
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .collection('bids')
                    .doc(uid)
                    .snapshots(),
                builder: (ctx2, bidSnap) {
                  bool alreadyBid =
                      hasBid || (bidSnap.hasData && bidSnap.data!.exists);
                  if (alreadyBid) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FundipapColors.greenSuccess.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: FundipapColors.greenSuccess.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: FundipapColors.greenSuccess,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have placed a bid. Wait for client feedback - You will receive KES $fundiReceives if accepted',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: FundipapColors.greenSuccess,
                              ),
                            ),
                          ),
                        ],
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
                    onPressed: () {
                      if (jobId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Job ID missing')),
                        );
                        return;
                      }
                      showDialog(
                        context: context,
                        builder: (_) =>
                            FundiBidDialog(jobId: jobId, jobData: job),
                      );
                    },
                    child: Text(
                      job['marketAvg'] != null
                          ? 'AVG KES ${job['marketAvg']}'
                          : 'KES ${job['budget'] ?? job['offeredPrice'] ?? ''} OFFERED • You get $fundiReceives',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(job['customerId'] ?? job['clientId'])
                  .get(),
              builder: (_, snap) {
                var client = snap.data?.data() as Map<String, dynamic>?;
                var name =
                    client?['username'] ??
                    client?['name'] ??
                    job['customerUsername'] ??
                    'Client';
                var rating = (client?['clientRating'] ?? 4.5).toDouble();
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: FundipapColors.blackGray,
                        child: Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                Text(
                                  ' $rating • ${client?['jobsPosted'] ?? 0} jobs',
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              ],
                            ),
                            Text(
                              job['location'] ?? 'Kisumu',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClientProfileScreen(
                              clientId: job['customerId'] ?? job['clientId'],
                            ),
                          ),
                        ),
                        child: Text(
                          'View Profile',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              job['title'] ?? 'Job',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Chip(
                  label: Text(
                    (job['category'] ?? 'General').toString().toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (distanceKm != null)
                  Chip(
                    label: Text(
                      '${distanceKm!.toStringAsFixed(1)} km away',
                      style: GoogleFonts.inter(fontSize: 10),
                    ),
                    backgroundColor: FundipapColors.primaryYellow,
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KES ${job['budget'] ?? ''} OFFERED',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (labour > 0)
                      Text(
                        'You receive: KES $fundiReceives',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // FUNDI RECEIPT PREVIEW
            if (labour > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your payout preview',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),
                    _row('Labour:', 'KES $labour'),
                    _row('Transport:', '+ KES $trans'),
                    _row('App maintenance:', '- KES $fFee'),
                    Divider(height: 12),
                    _row('You will receive:', 'KES $fundiReceives', bold: true),
                    Text(
                      'Client pays KES $clientLocks total, you get KES $fundiReceives',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Description',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              job['description'] ?? 'No description',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 20),
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
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false}) {
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
}
