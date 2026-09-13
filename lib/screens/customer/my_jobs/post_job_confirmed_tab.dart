import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ClientConfirmedTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Future<void> Function(
    BuildContext,
    String,
    Map<String, dynamic>,
    double,
  )
  onCounter;
  final Future<void> Function(String, Map<String, dynamic>, double)
  onAcceptReneg;
  final Future<void> Function(BuildContext, String, double) onPayEscrow;
  final Future<void> Function(String) onConfirmCompletion;
  const ClientConfirmedTab({
    super.key,
    required this.docs,
    required this.onCounter,
    required this.onAcceptReneg,
    required this.onPayEscrow,
    required this.onConfirmCompletion,
  });
  @override
  Widget build(BuildContext context) {
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
                                      await onAcceptReneg(jobId, reneg, agreed),
                                  child: const Text('Accept New Price'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => onCounter(
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
                      onPressed: () =>
                          onPayEscrow(context, jobId, agreed.toDouble()),
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
                    onPressed: () => onConfirmCompletion(jobId),
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
}
