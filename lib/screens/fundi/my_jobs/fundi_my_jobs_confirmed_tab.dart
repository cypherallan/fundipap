import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiConfirmedTab extends StatelessWidget {
  final Stream<QuerySnapshot> jobsStream;
  final Future<void> Function(String jobId) onMarkSiteVisited;
  final Future<void> Function(String jobId) onRequestNewPrice;
  final Future<void> Function(String jobId) onStartJob;
  final Future<void> Function(String jobId) onAddParts;
  final Future<void> Function(String jobId) onMarkCompleted;

  const FundiConfirmedTab({
    super.key,
    required this.jobsStream,
    required this.onMarkSiteVisited,
    required this.onRequestNewPrice,
    required this.onStartJob,
    required this.onAddParts,
    required this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
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
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
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
                              onPressed: () => onMarkSiteVisited(jobId),
                              child: const Text(
                                'Mark Site Visited',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => onRequestNewPrice(jobId),
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
                        onPressed: () => onStartJob(jobId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.greenSuccess,
                        ),
                        child: const Text(
                          'START JOB WITHOUT NEW PRICE',
                          style: TextStyle(color: Colors.white, fontSize: 11),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                                'totalCost': reneg['newPrice'],
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
                                            onRequestNewPrice(jobId),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                onPressed: () => onStartJob(jobId),
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
                                onPressed: () => onRequestNewPrice(jobId),
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
                                onPressed: () => onAddParts(jobId),
                                child: const Text('Add Part Receipt'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => onMarkCompleted(jobId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FundipapColors.primaryYellow,
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
    );
  }
}
