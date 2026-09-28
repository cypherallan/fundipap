import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';

class CustomerMyJobs extends StatelessWidget {
  const CustomerMyJobs({super.key});

  Future<void> _payToEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowHeldAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveNewPrice(String jobId, double newPrice) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'agreedPrice': newPrice,
      'budget': newPrice,
      'budgetMax': newPrice,
      'renegotiation.status': 'approved',
      'renegotiation.approvedAt': FieldValue.serverTimestamp(),
      'status': 'assigned',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _rejectNewPrice(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.status': 'rejected',
      'renegotiation.rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _confirmCompletion(String jobId) async {
    var doc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
    var j = doc.data() as Map<String, dynamic>;
    var reneg = j['renegotiation'] as Map<String, dynamic>?;
    int initialAmount =
        (j['escrowAmount'] ?? j['agreedPrice'] ?? j['budgetMax'] ?? 0).toInt();
    int extraAmount =
        (j['extraLaborAmount'] ??
                reneg?['extraLabor'] ??
                reneg?['pendingLabor'] ??
                0)
            .toInt();
    int newLaborTotal = (reneg?['newLaborTotal'] ?? 0).toInt();
    int totalRelease = newLaborTotal > 0
        ? newLaborTotal
        : initialAmount + extraAmount;
    if (totalRelease == 0) totalRelease = initialAmount;

    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
      'escrowStatus': 'released',
      'extraEscrowStatus': 'released',
      'clientConfirmedComplete': true,
      'completedAt': FieldValue.serverTimestamp(),
      'totalReleasedAmount': totalRelease,
      'fundiPayoutAmount': totalRelease,
      'initialEscrowReleased': initialAmount,
      'extraEscrowReleased': extraAmount,
      'fundiHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('customerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'You haven\'t posted any jobs yet',
              style: GoogleFonts.inter(),
            ),
          );
        }
        // FILTER OUT PENDING/OPEN - now on Home
        var allJobs = snap.data!.docs;
        var jobs = allJobs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          var status = (data['status'] ?? '').toString();
          return status != 'open' && status != 'pending';
        }).toList();

        if (jobs.isEmpty) {
          return Center(
            child: Text(
              'No active jobs — pending jobs are now on Home',
              style: GoogleFonts.inter(color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (_, i) {
            var doc = jobs[i];
            var j = doc.data() as Map<String, dynamic>;
            j['id'] = doc.id;
            String status = j['status'] ?? 'open';
            String escrow = j['escrowStatus'] ?? 'pending';
            bool siteDone = j['siteVisitDone'] ?? false;
            var reneg = j['renegotiation'] as Map<String, dynamic>?;
            int initialAmt =
                (j['escrowAmount'] ?? j['agreedPrice'] ?? j['budgetMax'] ?? 0)
                    .toInt();
            int extraAmt = (j['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0)
                .toInt();
            int newTotal = (reneg?['newLaborTotal'] ?? 0).toInt();
            int totalToRelease = newTotal > 0
                ? newTotal
                : initialAmt + extraAmt;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          j['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    j['description'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KES ${j['budgetMin']} - ${j['budgetMax']} • Agreed: KES ${j['agreedPrice'] ?? '-'} • Extra: KES $extraAmt • Total: KES $totalToRelease',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),

                  if (siteDone) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fundi visited site',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                if (j['siteVisitFindings'] != null)
                                  Text(
                                    j['siteVisitFindings'],
                                    style: GoogleFonts.inter(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (reneg != null && reneg['status'] == 'pending') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fundi requests new price: KES ${reneg['newPrice']}',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${reneg['reason'] ?? ''}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _rejectNewPrice(doc.id),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(color: Colors.black),
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
                                  onPressed: () => _approveNewPrice(
                                    doc.id,
                                    (reneg['newPrice'] as num).toDouble(),
                                  ),
                                  child: const Text(
                                    'Approve & Pay Diff',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (status == 'assigned' && escrow != 'held') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.primaryYellow,
                        ),
                        onPressed: () => _payToEscrow(
                          doc.id,
                          (j['agreedPrice'] ?? j['budgetMax'] ?? 1000)
                              .toDouble(),
                        ),
                        child: Text(
                          'PAY KES ${j['agreedPrice'] ?? j['budgetMax']} TO ESCROW (Mpesa)',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (status == 'in_progress') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        'Fundi is working... Initial KES $initialAmt + Extra KES $extraAmt = Total KES $totalToRelease in escrow',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  if (status == 'job_completed' ||
                      status == 'pending_completion') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fundi marked job as completed',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            'Initial: KES $initialAmt + Extra: KES $extraAmt = Total KES $totalToRelease will be released to fundi',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.greenSuccess,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () => _confirmCompletion(doc.id),
                        child: Text(
                          'CONFIRM COMPLETION & RELEASE KES $totalToRelease TO FUNDI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],

                  if (status == 'completed') ...[
                    const SizedBox(height: 10),
                    Text(
                      '✓ Completed & Paid KES ${j['totalReleasedAmount'] ?? totalToRelease} (Initial $initialAmt + Extra $extraAmt)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
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
  }
}
