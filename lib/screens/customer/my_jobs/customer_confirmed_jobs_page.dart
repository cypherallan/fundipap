import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../confirm/client_price_approval_screen.dart';

class CustomerConfirmedJobsPage extends StatelessWidget {
  const CustomerConfirmedJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirmed Jobs',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('customerId', isEqualTo: uid)
            .where(
              'status',
              whereIn: [
                'assigned',
                'confirmed',
                'travelling',
                'site_visit',
                'in_progress',
                'pending_completion',
                'job_completed',
              ],
            )
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text('No confirmed jobs', style: GoogleFonts.inter()),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              var job = docs[i].data() as Map<String, dynamic>;
              var jobId = docs[i].id;
              var reneg = job['renegotiation'] as Map<String, dynamic>?;
              double agreed = (job['agreedPrice'] ?? job['budget'] ?? 0)
                  .toDouble();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'KES $agreed • ${job['status']} • Escrow: ${job['escrowStatus']}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      if (reneg != null &&
                          reneg['requested'] == true &&
                          reneg['status'] != 'accepted') ...[
                        const SizedBox(height: 8),
                        Container(
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
                                'Fundi requests new price after visit',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Reason: ${reneg['reason'] ?? ''}',
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Extra KES ${reneg['extraLabor'] ?? 0} • Total labor KES ${reneg['newLaborTotal'] ?? reneg['newPrice']}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClientPriceApprovalScreen(
                                        jobId: jobId,
                                        job: job,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'REVIEW BREAKDOWN & PHOTOS',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
