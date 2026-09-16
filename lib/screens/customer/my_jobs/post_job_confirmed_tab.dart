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
                // === HEADER: JOB COMPLETED vs FUNDI WORKING ===
                if (reneg != null &&
                    (reneg['currentPhase'] == 'completed_by_fundi' ||
                        job['status'] == 'job_completed' ||
                        job['status'] == 'pending_completion'))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Job Completed - Review & Release Payment',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (reneg != null &&
                    (reneg['currentPhase'] == 'fundi_working' ||
                        reneg['currentPhase'] == 'parts_confirmed_by_fundi'))
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: reneg['currentPhase'] == 'fundi_working'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: reneg['currentPhase'] == 'fundi_working'
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          reneg['currentPhase'] == 'fundi_working'
                              ? Icons.construction
                              : Icons.check_circle,
                          size: 18,
                          color: reneg['currentPhase'] == 'fundi_working'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reneg['currentPhase'] == 'fundi_working'
                                    ? 'Fundi is working...'
                                    : 'Fundi confirmed parts - starting work',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color:
                                      reneg['currentPhase'] == 'fundi_working'
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                              ),
                              Text(
                                'Labor KES ${reneg['newLaborTotal'] ?? agreed.toInt()} in escrow • Parts: ${(job['parts'] ?? []).length}',
                                style: GoogleFonts.inter(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        if (reneg['currentPhase'] == 'fundi_working')
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),

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
                        if (reneg['status'] ==
                            'accepted_client_buys_parts') ...[
                          const SizedBox(height: 8),
                          if (reneg['currentPhase'] ==
                              'waiting_for_client_to_buy_parts')
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(jobId)
                                      .update({
                                        'renegotiation.currentPhase':
                                            'client_claims_parts_bought',
                                        'renegotiation.clientPartsBought': true,
                                        'renegotiation.clientPartsBoughtAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                },
                                child: Text(
                                  'I HAVE BOUGHT PARTS - Notify Fundi',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          if (reneg['currentPhase'] ==
                              'client_claims_parts_bought')
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'You marked parts as bought. Waiting for fundi to confirm parts available...',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                          if (reneg['currentPhase'] ==
                              'parts_confirmed_by_fundi')
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✓ Fundi confirmed parts available. He will start work now.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (reneg['currentPhase'] == 'fundi_working')
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Fundi is working...',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (reneg['currentPhase'] == 'completed_by_fundi' ||
                              job['status'] == 'job_completed')
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Text(
                                '✓ Job Completed - Fundi finished. Please confirm to release KES ${reneg['newLaborTotal'] ?? agreed.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 8),
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
                if (job['status'] == 'pending_completion' ||
                    job['status'] == 'job_completed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.greenSuccess,
                      ),
                      onPressed: () => onConfirmCompletion(jobId),
                      child: const Text(
                        'Confirm Completion & Release Payment',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
