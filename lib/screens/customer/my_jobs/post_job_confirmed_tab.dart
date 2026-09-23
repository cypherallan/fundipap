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
    if (docs.isEmpty)
      return Center(
        child: Text('No confirmed jobs', style: GoogleFonts.inter()),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var doc = docs[i];
        var job = doc.data() as Map<String, dynamic>;
        var jobId = doc.id;
        double agreed = (job['agreedPrice'] ?? job['budget'] ?? 0).toDouble();
        String escrow = job['escrowStatus'] ?? 'pending';
        String fundiName = (job['assignedFundiName'] ?? 'Fundi').toString();
        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        String phase = (reneg?['currentPhase'] ?? '').toString();
        String status = (job['status'] ?? '').toString();

        int initialAmt =
            (job['escrowAmount'] ?? job['agreedPrice'] ?? agreed.toInt() ?? 0)
                .toInt();
        int extraAmt = (job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0)
            .toInt();
        int newTotal = (reneg?['newLaborTotal'] ?? 0).toInt();
        int totalToRelease = newTotal > 0 ? newTotal : initialAmt + extraAmt;
        if (totalToRelease == 0) totalToRelease = initialAmt;

        bool showRenegCard =
            reneg != null &&
            reneg['requested'] == true &&
            reneg['status'] != 'accepted';
        bool isCompletedByFundi =
            phase == 'completed_by_fundi' ||
            status == 'job_completed' ||
            status == 'pending_completion';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCompletedByFundi)
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
                            'Job Completed by $fundiName - Review & Release Payment',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Text(
                  job['title'] ?? '',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$fundiName • Agreed: KES $agreed • Total to release: KES $totalToRelease • $status',
                  style: GoogleFonts.inter(fontSize: 11),
                ),

                if (isCompletedByFundi) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Initial Escrow:',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                            Text(
                              'KES $initialAmt',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (extraAmt > 0)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '+ Extra Labor:',
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                              Text(
                                'KES $extraAmt',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total to $fundiName:',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'KES $totalToRelease',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.greenSuccess,
                      ),
                      onPressed: () async {
                        await onConfirmCompletion(jobId);
                        if (!context.mounted) return;
                        // SUCCESS MESSAGE
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Payment Released! 🎉',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You have confirmed completion.',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'KES $totalToRelease released to $fundiName (Initial KES $initialAmt + Extra KES $extraAmt)',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'CONFIRM COMPLETION & RELEASE KES $totalToRelease TO ${fundiName.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],

                if (showRenegCard) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ClientPriceApprovalScreen(jobId: jobId, job: job),
                        ),
                      ),
                      child: Text(
                        'REVIEW BREAKDOWN - Extra KES ${reneg?['extraLabor'] ?? 0}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],

                if (escrow == 'pending')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                      ),
                      onPressed: () =>
                          onPayEscrow(context, jobId, agreed.toDouble()),
                      child: Text(
                        'Pay KES $agreed to Escrow',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Colors.black,
                        ),
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
