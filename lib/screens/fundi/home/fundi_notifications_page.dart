import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/fundi_request_new_price.dart';
import 'fundi_visit_customer_tab.dart'; // <-- real VisitCustomerScreen lives here

class FundiNotificationsPage extends StatelessWidget {
  const FundiNotificationsPage({super.key});

  Future<void> _startSiteVisit(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisitCustomerScreen(jobId: jobId, job: job),
      ),
    );
  }

  void _openNewPrice(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundiRequestNewPriceScreen(jobId: jobId, job: job),
      ),
    );
  }

  Future<void> _startJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
      builder: (context, jobsSnap) {
        Map<String, Map<String, dynamic>> grouped = {};

        if (jobsSnap.hasData) {
          for (var doc in jobsSnap.data!.docs) {
            var job = doc.data() as Map<String, dynamic>;
            bool isMine =
                job['assignedFundiId'] == uid ||
                job['assignedFundi'] == uid ||
                job['fundiId'] == uid ||
                job['acceptedFundiId'] == uid;
            if (!isMine) continue;
            grouped[doc.id] = {
              'jobId': doc.id,
              'job': job,
              'clientName':
                  (job['customerName'] ?? job['clientName'] ?? 'Client')
                      .toString(),
              'category': (job['category'] ?? job['title'] ?? 'Job').toString(),
              'latestAt': (job['updatedAt'] is Timestamp)
                  ? (job['updatedAt'] as Timestamp).toDate()
                  : DateTime.now(),
            };
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('bids')
              .where('fundiId', isEqualTo: uid)
              .where('status', isEqualTo: 'accepted')
              .snapshots(),
          builder: (context, bidsSnap) {
            if (bidsSnap.hasData) {
              for (var b in bidsSnap.data!.docs) {
                var bid = b.data() as Map<String, dynamic>;
                var jobId = (bid['jobId'] ?? '').toString();
                if (grouped.containsKey(jobId)) continue;
                grouped[jobId] = {
                  'jobId': jobId,
                  'job': {
                    'title': bid['jobTitle'],
                    'customerName': bid['customerName'] ?? 'Client',
                  },
                  'clientName': (bid['customerName'] ?? 'Client').toString(),
                  'category': (bid['jobTitle'] ?? 'Job').toString(),
                  'latestAt': DateTime.now(),
                  'isBidOnly': true,
                };
              }
            }

            var list = grouped.values.toList()
              ..sort(
                (a, b) => (b['latestAt'] as DateTime).compareTo(
                  a['latestAt'] as DateTime,
                ),
              );
            if (list.isEmpty)
              return Center(
                child: Text('No notifications', style: GoogleFonts.inter()),
              );

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                var g = list[i];
                var job = g['job'] as Map<String, dynamic>;
                var clientName = g['clientName'] as String;
                var category = g['category'] as String;
                var jobId = g['jobId'] as String;
                var escrow = (job['escrowStatus'] ?? 'pending').toString();
                var status = (job['status'] ?? '').toString();
                bool siteDone = job['siteVisitDone'] == true;
                var reneg = job['renegotiation'] as Map<String, dynamic>?;

                // Determine current card state
                if (g['isBidOnly'] == true) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: FundipapColors.blackGray,
                        child: Text(
                          clientName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        category,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '$clientName • Waiting for escrow',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      trailing: const Icon(
                        Icons.verified,
                        color: Colors.orange,
                      ),
                    ),
                  );
                }

                if ((escrow == 'paid' || escrow == 'held') &&
                    (status == 'assigned' || status == 'confirmed')) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: FundipapColors.blackGray,
                              child: Text(
                                clientName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              clientName,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              category,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
                        Text(
                          'Client paid to escrow!',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'KES ${job['escrowAmount'] ?? job['agreedPrice'] ?? ''} locked • ${job['title'] ?? ''}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FundipapColors.blackGray,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            icon: const Icon(Icons.navigation, size: 20),
                            label: Text(
                              'Start Site Visit - Must Visit First',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () =>
                                _startSiteVisit(context, jobId, job),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if ((job['travelling'] == true || status == 'travelling') &&
                    !siteDone) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: FundipapColors.blackGray,
                          child: Text(
                            clientName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$clientName • ${job['title'] ?? ''} • ${(job['fundiLiveDistance'] ?? 0).toStringAsFixed(0)}m away',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (siteDone &&
                    status == 'site_visit' &&
                    (reneg == null || reneg['requested'] != true)) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FundipapColors.greenSuccess),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: FundipapColors.blackGray,
                              child: Text(
                                clientName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              clientName,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              category,
                              style: GoogleFonts.inter(fontSize: 10),
                            ),
                          ],
                        ),
                        const Divider(height: 14),
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _startJob(jobId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FundipapColors.greenSuccess,
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
                                    _openNewPrice(context, jobId, job),
                                child: const Text('Request New Price'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: FundipapColors.blackGray,
                      child: Text(
                        clientName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      category,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      clientName,
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
