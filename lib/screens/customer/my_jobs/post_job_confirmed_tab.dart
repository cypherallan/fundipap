import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../customer/confirm/client_price_approval_screen.dart';

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
                      border: Border.all(color: Colors.orange, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber,
                              color: Colors.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                reneg['status'] == 'countered_by_client'
                                    ? 'You countered KES ${reneg['newPrice'] ?? reneg['counterPrice']}'
                                    : 'Fundi requests new price after visit',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // NEW STRUCTURE SUPPORT
                        if (reneg['reasons'] != null)
                          Wrap(
                            spacing: 4,
                            children: (List<String>.from(reneg['reasons']))
                                .map(
                                  (r) => Chip(
                                    label: Text(
                                      r,
                                      style: GoogleFonts.inter(fontSize: 9),
                                    ),
                                    backgroundColor: FundipapColors
                                        .primaryYellow
                                        .withOpacity(0.3),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          )
                        else
                          Text(
                            'Reason: ${reneg['reason']}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),

                        const SizedBox(height: 6),
                        // NEW BREAKDOWN PREVIEW
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Builder(
                            builder: (_) {
                              int old =
                                  (reneg['oldLabor'] ??
                                          reneg['oldPrice'] ??
                                          agreed.toInt())
                                      as int;
                              int extra =
                                  (reneg['extraLabor'] ??
                                          reneg['pendingLabor'] ??
                                          0)
                                      as int;
                              int newLab =
                                  (reneg['newLaborTotal'] ??
                                          reneg['newPrice'] ??
                                          old + extra)
                                      as int;
                              int parts =
                                  (reneg['partsEstimateTotal'] ??
                                          reneg['partsTotal'] ??
                                          0)
                                      as int;
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Old Labor:',
                                        style: GoogleFonts.inter(fontSize: 10),
                                      ),
                                      Text(
                                        'KES $old',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (extra > 0)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '+ Extra Labor:',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          'KES $extra',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'New Labor Total:',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'KES $newLab',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (parts > 0)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '+ Parts (shop direct):',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          'KES $parts',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const Divider(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Escrow (labor only):',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        'KES $newLab',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 8),
                        // OPEN DETAILED SCREEN
                        if (reneg['status'] == 'pending' ||
                            reneg['status'] == 'countered_by_fundi')
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
                                'REVIEW BREAKDOWN & PHOTOS - Extra KES ${reneg['extraLabor'] ?? reneg['pendingLabor'] ?? 0}',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else if (reneg['status'] == 'countered_by_client')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Waiting for fundi to accept your KES ${reneg['counterPrice'] ?? reneg['newPrice']}...',
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
