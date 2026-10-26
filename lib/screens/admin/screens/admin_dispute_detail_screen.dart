import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../fundi/services/fundi_penalty_service.dart';

class AdminDisputeDetailScreen extends StatefulWidget {
  final String disputeId;
  const AdminDisputeDetailScreen({super.key, required this.disputeId});
  @override
  State<AdminDisputeDetailScreen> createState() =>
      _AdminDisputeDetailScreenState();
}

class _AdminDisputeDetailScreenState extends State<AdminDisputeDetailScreen> {
  bool resolving = false;
  final reasonCtrl = TextEditingController();

  Widget _copyRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _traceCard(
    Map<String, dynamic> d,
    Map<String, dynamic>? job,
    Map<String, dynamic>? fundi,
    Map<String, dynamic>? client,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRACE - ${widget.disputeId}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const Divider(),
          Text(
            'JOB',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: Colors.blue.shade800,
            ),
          ),
          _copyRow('JobId', d['jobId']),
          _copyRow('Title', job?['title'] ?? d['jobTitle'] ?? '—'),
          _copyRow('Category', job?['category'] ?? job?['trade'] ?? '—'),
          _copyRow('Status', job?['status']?.toString() ?? '—'),
          Text(
            'Labour ${job?['labourCost'] ?? job?['amount'] ?? d['escrowAmount'] ?? 'null'} | Transport ${job?['transportFee'] ?? 0} | Total ${job?['totalAmount'] ?? job?['finalAmount'] ?? 'null'} | Payout ${job?['fundiPayoutAmount'] ?? 'null'}',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'CLIENT',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: Colors.green.shade800,
            ),
          ),
          _copyRow('ClientId', d['clientId'] ?? job?['clientId']),
          _copyRow(
            'Name',
            client?['name'] ?? d['clientName'] ?? job?['clientName'],
          ),
          _copyRow('Phone', client?['phone'] ?? job?['clientPhone']),
          const SizedBox(height: 8),
          Text(
            'FUNDI',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: Colors.orange.shade800,
            ),
          ),
          _copyRow('FundiId', d['fundiId'] ?? job?['fundiId']),
          _copyRow(
            'Name',
            fundi?['name'] ?? d['fundiName'] ?? job?['fundiName'],
          ),
          _copyRow('Phone', fundi?['phone'] ?? job?['fundiPhone']),
          _copyRow('Badge', fundi?['badge']?.toString() ?? '—'),
          const SizedBox(height: 8),
          Text(
            'TRANSACTION',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: Colors.red.shade800,
            ),
          ),
          _copyRow('C2B', d['c2bId'] ?? job?['c2bTransactionId']),
          _copyRow('B2C', d['b2cId'] ?? job?['b2cTransactionId']),
          _copyRow(
            'Amount',
            'KES ${d['escrowAmount'] ?? d['amount'] ?? job?['totalAmount'] ?? 'null'}',
          ),
          _copyRow('Reason', d['reason']),
        ],
      ),
    );
  }

  Future<void> resolveClientWinWithRedoOffer(Map<String, dynamic> d) async {
    if (reasonCtrl.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Write reason why client won - fundi will see this'),
        ),
      );
      return;
    }
    setState(() => resolving = true);
    DateTime now = DateTime.now();
    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(widget.disputeId)
        .update({
          'status': 'resolved_client_win_pending_redo',
          'winner': 'client',
          'adminReason': reasonCtrl.text.trim(),
          'redoOffer': {
            'createdAt': FieldValue.serverTimestamp(),
            'deadline': Timestamp.fromDate(now.add(const Duration(hours: 24))),
            'extendedDeadline': Timestamp.fromDate(
              now.add(const Duration(hours: 30)),
            ),
            'decision': null,
            'reminderSent': false,
          },
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': 'admin',
          'nextStep': 'awaiting_fundi_redo_decision',
        });
    await FirebaseFirestore.instance.collection('jobs').doc(d['jobId']).update({
      'status': 'awaiting_fundi_redo_decision',
      'escrowStatus': 'held_pending_redo_decision',
    });
    setState(() => resolving = false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> sendReminder(Map<String, dynamic> d) async {
    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(widget.disputeId)
        .update({
          'redoOffer.reminderSent': true,
          'redoOffer.reminderSentAt': FieldValue.serverTimestamp(),
          'status': 'resolved_client_win_reminder_sent',
        });
  }

  Future<void> applyDeductionAfterNoResponse(Map<String, dynamic> d) async {
    await FundiPenaltyService.onRepeatJobNoRedo(
      fundiId: d['fundiId'],
      disputeId: widget.disputeId,
      clientId: d['clientId'],
      clientName: d['clientName'] ?? 'client',
      jobId: d['jobId'],
      disputedJobAmount: (d['escrowAmount'] ?? 0).toDouble(),
    );
    await FirebaseFirestore.instance.collection('jobs').doc(d['jobId']).update({
      'status': 'refunded',
      'escrowStatus': 'refunded',
    });
    if (mounted) Navigator.pop(context);
  }

  // NEW: Payment dispute admin actions
  Future<void> markMpesaSuccess(Map<String, dynamic> d) async {
    setState(() => resolving = true);
    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(widget.disputeId)
        .update({
          'status': 'auto_resolved_mpesa_success',
          'adminAction': 'mpesa_proven_success',
          'adminNote': reasonCtrl.text.trim().isEmpty
              ? 'M-Pesa B2C shows SUCCESS - fundi received'
              : reasonCtrl.text.trim(),
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': 'admin',
        });
    setState(() => resolving = false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> retryPayout(Map<String, dynamic> d) async {
    setState(() => resolving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'retryFundiPayoutSecure',
      );
      await callable.call({'jobId': d['jobId'], 'disputeId': widget.disputeId});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('B2C Retry triggered - check mpesaPayouts'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
    }
    setState(() => resolving = false);
  }

  Widget evidenceBox(String title, Map? evidence) {
    if (evidence == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '$title: Not yet submitted',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.red),
          ),
        ),
      );
    }
    return Card(
      color: title.contains('Reporter')
          ? Colors.blue.shade50
          : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              evidence['statement'] ?? '',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            if ((evidence['photos'] as List? ?? []).isNotEmpty)
              Wrap(
                children: (evidence['photos'] as List)
                    .map(
                      (u) => Padding(
                        padding: const EdgeInsets.all(2),
                        child: Image.network(
                          u,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .doc(widget.disputeId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        var d = snap.data!.data() as Map<String, dynamic>;
        bool isRepeat = d['type'] == 'repeat_job';
        bool isPayment =
            (d['reason'] ?? '').toString().toLowerCase().contains('payment') ||
            d.containsKey('partialAmount') ||
            (d['description'] ?? '').toString().contains('mpesaPayouts');
        var redoOffer = d['redoOffer'] as Map?;
        DateTime? deadline = (redoOffer?['deadline'] as Timestamp?)?.toDate();
        bool overdue = deadline != null && DateTime.now().isAfter(deadline);
        DateTime? extDeadline = (redoOffer?['extendedDeadline'] as Timestamp?)
            ?.toDate();
        bool extOverdue =
            extDeadline != null && DateTime.now().isAfter(extDeadline);

        String autoResult = (d['autoCheckResult'] ?? d['autoCheckStatus'] ?? '')
            .toString();
        String autoTier = (d['autoCheckTier'] ?? '').toString();
        String autoMsg = (d['autoCheckMessage'] ?? d['autoExplain'] ?? '')
            .toString();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Admin - ${d['type']} ${isPayment ? '💰 PAYMENT' : ''}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(d['jobId'])
                      .get(),
                  builder: (_, jobSnap) {
                    var job = jobSnap.data?.data() as Map<String, dynamic>?;
                    return FutureBuilder<DocumentSnapshot?>(
                      future: d['fundiId'] != null
                          ? FirebaseFirestore.instance
                                .collection('fundis')
                                .doc(d['fundiId'])
                                .get()
                          : Future<DocumentSnapshot?>.value(null),
                      builder: (_, fundiSnap) {
                        var fundi =
                            fundiSnap.data?.data() as Map<String, dynamic>?;
                        return FutureBuilder<DocumentSnapshot?>(
                          future: d['clientId'] != null
                              ? FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(d['clientId'])
                                    .get()
                              : Future<DocumentSnapshot?>.value(null),
                          builder: (_, clientSnap) {
                            var client =
                                clientSnap.data?.data()
                                    as Map<String, dynamic>?;
                            return _traceCard(d, job, fundi, client);
                          },
                        );
                      },
                    );
                  },
                ),
                const Divider(),

                // PAYMENT DISPUTE LEDGER - KRA SAFE
                if (isPayment) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💰 PAYMENT DISPUTE - MPESA LEDGER',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dispute: ${d['description'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 10),
                        ),
                        const Divider(),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('mpesaPayouts')
                              .doc(d['jobId'])
                              .get(),
                          builder: (_, pSnap) {
                            if (!pSnap.hasData)
                              return const CircularProgressIndicator();
                            if (!pSnap.data!.exists)
                              return Text(
                                '❌ mpesaPayouts/${d['jobId']} NOT FOUND - escrow.ts did not run!',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            var pd = pSnap.data!.data() as Map<String, dynamic>;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'C2B (Client→Business): ${pd['c2bTransactionId']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'B2C (Business→Fundi): ${pd['b2cTransactionId']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Amount: KES ${pd['amount']} | Fee: ${pd['platformFee']} | Labour: ${pd['labourCost']} | Transport: ${pd['transportFee']}',
                                  style: GoogleFonts.inter(fontSize: 10),
                                ),
                                Text(
                                  'Status: ${pd['b2cStatus'] ?? pd['status']} | IdempotencyKey: ${pd['idempotencyKey'] ?? d['jobId']}',
                                  style: GoogleFonts.inter(fontSize: 10),
                                ),
                                Text(
                                  'C2B vs B2C different? ${pd['c2bTransactionId'] != pd['b2cTransactionId'] ? 'YES ✓ KRA SAFE' : 'NO ❌ SAME ID - BUG'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color:
                                        pd['c2bTransactionId'] !=
                                            pd['b2cTransactionId']
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                if (pd['deductionThisJob'] != null &&
                                    (pd['deductionThisJob'] as num) > 0)
                                  Text(
                                    'Deduction: KES ${pd['deductionThisJob']} | Original: ${pd['baseFundiPayoutBeforeDeduction']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const Divider(),
                        FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('jobs')
                              .doc(d['jobId'])
                              .get(),
                          builder: (_, jSnap) {
                            if (!jSnap.hasData || !jSnap.data!.exists)
                              return const SizedBox();
                            var jd = jSnap.data!.data() as Map<String, dynamic>;
                            var rel =
                                jd['paymentReleasedAt'] ?? jd['releasedAt'];
                            String relStr = rel is Timestamp
                                ? rel.toDate().toString()
                                : rel.toString();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Job Status: ${jd['status']} | Escrow: ${jd['escrowStatus']}',
                                  style: GoogleFonts.inter(fontSize: 10),
                                ),
                                Text(
                                  'ReleasedAt: $relStr | FundiPayoutApplied: ${jd['fundiPayoutApplied']}',
                                  style: GoogleFonts.inter(fontSize: 10),
                                ),
                                Text(
                                  'FundiPayoutAmount (server truth): KES ${jd['fundiPayoutAmount']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if (autoResult.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: autoResult.contains('success')
                                  ? Colors.green.shade100
                                  : autoResult.contains('explained')
                                  ? Colors.blue.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: autoResult.contains('success')
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AUTO-CHECK T$autoTier: ${autoResult.toUpperCase()}',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  autoMsg,
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Admin note / explanation to fundi',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                ),
                                onPressed: resolving
                                    ? null
                                    : () => markMpesaSuccess(d),
                                child: const Text(
                                  'M-Pesa Success - Fundi Lying',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                ),
                                onPressed: resolving
                                    ? null
                                    : () => retryPayout(d),
                                child: const Text(
                                  'Retry B2C (if FAILED)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('disputes')
                                  .doc(widget.disputeId)
                                  .update({
                                    'status': 'resolved_explained',
                                    'adminNote': reasonCtrl.text.trim(),
                                    'resolvedAt': FieldValue.serverTimestamp(),
                                  });
                              if (mounted) Navigator.pop(context);
                            },
                            child: const Text(
                              'Explain Deduction/Fee & Close',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                ],

                // REPEAT JOB EVIDENCE (existing)
                evidenceBox(
                  'Reporter (${d['reporterRole']})',
                  d['reporterEvidence'],
                ),
                evidenceBox('Reported', d['reportedEvidence']),
                const Divider(),

                if (!isRepeat && !isPayment) ...[
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Admin reason (optional for non-repeat)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('disputes')
                          .doc(widget.disputeId)
                          .update({
                            'status': 'resolved_fundi_win',
                            'winner': 'fundi',
                          });
                    },
                    child: const Text('Fundi Won - Release'),
                  ),
                ],
                if (isRepeat) ...[
                  Text(
                    'REPEAT JOB FLOW (14 days)',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (d['status'] == 'open' ||
                      d['status'] == 'evidence_complete') ...[
                    Text(
                      '1. Write why client won - fundi will see this reason + option to redo',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g. Video shows socket still not working after your fix...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                        ),
                        onPressed: resolving
                            ? null
                            : () => resolveClientWinWithRedoOffer(d),
                        child: const Text(
                          'Resolve Client Won + Offer Redo (24h)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                  if (d['status'] == 'resolved_client_win_pending_redo') ...[
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Offer sent to fundi. Deadline: $deadline. Fundi sees reason: ${d['adminReason']}\nHe has 24h to accept redo. Do NOT mention 50% deduction.',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ),
                    ),
                    if (overdue && redoOffer?['reminderSent'] != true) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => sendReminder(d),
                        child: const Text('24h passed - Send 6h reminder'),
                      ),
                    ],
                    if (redoOffer?['reminderSent'] == true)
                      Text(
                        'Reminder sent. Extended deadline: $extDeadline',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                    if (extOverdue)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                        onPressed: () => applyDeductionAfterNoResponse(d),
                        child: const Text(
                          '30h passed - Apply 50% Deduction',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
