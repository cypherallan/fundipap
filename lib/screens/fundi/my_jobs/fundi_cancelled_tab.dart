import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../fundi/home/fundi_customer_timeline_page.dart';

class FundiCancelledTab extends StatelessWidget {
  final Stream<QuerySnapshot> jobsStream;
  const FundiCancelledTab({super.key, required this.jobsStream});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: jobsStream,
      builder: (_, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        var docs = snap.data!.docs.where((d) {
          var status = ((d.data() as Map)['status'] ?? '')
              .toString()
              .toLowerCase();
          return status.contains('cancel');
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No cancelled jobs',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            var doc = docs[i];
            var job = doc.data() as Map<String, dynamic>;
            bool byClient = (job['cancelledBy'] ?? '') == 'client';
            bool afterArrival = job['status'] == 'cancelled_after_arrival';
            int transport =
                (job['transportFee'] ?? job['fundiPayout'] ?? 0) as int;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'CANCELLED',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        byClient ? 'By Client' : 'By You',
                        style: GoogleFonts.inter(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason: ${job['cancelReason'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        if (byClient && afterArrival)
                          Text(
                            'You get transport: KES $transport',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade700,
                            ),
                          ),
                        if (byClient && !afterArrival)
                          Text(
                            'Cancelled before travel - no payout',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        if (!byClient)
                          Text(
                            'You cancelled - counts to your rate',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.red.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // NEW LOGIC FOR REPOSTED JOB BUTTON
                  FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('jobs')
                        .where('repostedFrom', isEqualTo: doc.id)
                        .limit(1)
                        .get(),
                    builder: (ctx, repSnap) {
                      if (!repSnap.hasData || repSnap.data!.docs.isEmpty)
                        return const SizedBox();
                      var newDoc = repSnap.data!.docs.first;
                      var newJob = newDoc.data() as Map<String, dynamic>;
                      var escrow = (newJob['escrowStatus'] ?? '').toString();
                      var status = (newJob['status'] ?? '')
                          .toString()
                          .toLowerCase();
                      bool escrowLocked =
                          [
                            'held',
                            'paid',
                            'locked',
                            'released',
                          ].contains(escrow) ||
                          status != 'open';

                      if (escrowLocked) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.black54,
                              ),
                              icon: const Icon(Icons.block, size: 14),
                              label: Text(
                                'Job Unavailable',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              onPressed: null,
                            ),
                          ),
                        );
                      }

                      // Check if fundi already placed bid on reposted job
                      return FutureBuilder<QuerySnapshot>(
                        future: newDoc.reference
                            .collection('bids')
                            .where('fundiId', isEqualTo: uid)
                            .limit(1)
                            .get(),
                        builder: (ctx2, bidSnap) {
                          bool alreadyBid =
                              bidSnap.hasData && bidSnap.data!.docs.isNotEmpty;
                          if (alreadyBid) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade100,
                                    foregroundColor: Colors.green.shade800,
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 14,
                                  ),
                                  label: Text(
                                    'You already placed a bid for this job',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                  onPressed: null,
                                ),
                              ),
                            );
                          }
                          // Else show VIEW NEW JOB
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.refresh, size: 14),
                                label: Text(
                                  'CLIENT REPOSTED - VIEW NEW JOB',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FundiCustomerTimelinePage(
                                      jobId: newDoc.id,
                                      clientName:
                                          newJob['customerName'] ?? 'Client',
                                      jobTitle: newJob['title'] ?? '',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
