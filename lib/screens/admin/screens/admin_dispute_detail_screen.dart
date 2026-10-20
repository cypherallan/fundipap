import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          'status':
              'resolved_client_win_pending_redo', // not fully resolved yet
          'winner': 'client',
          'adminReason': reasonCtrl.text.trim(),
          'redoOffer': {
            'createdAt': FieldValue.serverTimestamp(),
            'deadline': Timestamp.fromDate(now.add(Duration(hours: 24))),
            'extendedDeadline': Timestamp.fromDate(
              now.add(Duration(hours: 30)),
            ), // 24+6
            'decision': null,
            'reminderSent': false,
          },
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': 'admin',
          'nextStep': 'awaiting_fundi_redo_decision',
        });
    // job stays refunded but waiting for redo decision
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
    String fundiId = d['fundiId'];
    String clientId = d['clientId'];
    double jobAmount = (d['escrowAmount'] ?? 0).toDouble();
    double refund50 = jobAmount * 0.5;

    var fundiDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(fundiId)
        .get();
    int strikes = (fundiDoc.data()?['strikes'] ?? 0) as int;

    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(widget.disputeId)
        .update({
          'status': 'resolved_client_win_fundi_no_redo',
          'resolutionAction': 'deduct_50_next_job',
          'deductionAmount': refund50,
          'deductionOwedToClientId': clientId,
          'deductionOwedToClientName': d['clientName'],
          'deductionRemaining': refund50, // will deduct until this is 0
          'fundiDeclinedRedo': true,
        });

    await FirebaseFirestore.instance.collection('fundis').doc(fundiId).update({
      'strikes': strikes + 1,
      'pendingDeduction': FieldValue.increment(refund50),
      'pendingDeductionDisputeId': widget.disputeId,
      'pendingDeductionClientId': clientId,
      'pendingDeductionRemaining': refund50,
      'lastStrikeReason': 'repeat_job - no redo after 30h',
      'strikeUpdatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('jobs').doc(d['jobId']).update({
      'status': 'refunded',
      'escrowStatus': 'refunded',
    });

    if (mounted) Navigator.pop(context);
  }

  Widget evidenceBox(String title, Map? evidence) {
    if (evidence == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(12),
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
        padding: EdgeInsets.all(12),
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
            SizedBox(height: 6),
            Text(
              evidence['statement'] ?? '',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            if ((evidence['photos'] as List? ?? []).isNotEmpty)
              Wrap(
                children: (evidence['photos'] as List)
                    .map(
                      (u) => Image.network(
                        u,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
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
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        var d = snap.data!.data() as Map<String, dynamic>;
        bool isRepeat = d['type'] == 'repeat_job';
        var redoOffer = d['redoOffer'] as Map?;
        DateTime? deadline = (redoOffer?['deadline'] as Timestamp?)?.toDate();
        bool overdue = deadline != null && DateTime.now().isAfter(deadline);
        DateTime? extDeadline = (redoOffer?['extendedDeadline'] as Timestamp?)
            ?.toDate();
        bool extOverdue =
            extDeadline != null && DateTime.now().isAfter(extDeadline);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Admin - ${d['type']}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job: ${d['jobTitle']} | KES ${d['escrowAmount']}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Reason: ${d['reason']}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                Divider(),
                evidenceBox(
                  'Reporter (${d['reporterRole']})',
                  d['reporterEvidence'],
                ),
                evidenceBox('Reported', d['reportedEvidence']),
                Divider(),
                if (!isRepeat) ...[
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Admin reason (optional for non-repeat)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
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
                    child: Text('Fundi Won - Release'),
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
                  SizedBox(height: 8),
                  if (d['status'] == 'open' ||
                      d['status'] == 'evidence_complete') ...[
                    Text(
                      '1. Write why client won - fundi will see this reason + option to redo',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'e.g. Video shows socket still not working after your fix on 10 Oct... client within 14 days...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                        ),
                        onPressed: resolving
                            ? null
                            : () => resolveClientWinWithRedoOffer(d),
                        child: Text(
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
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Offer sent to fundi. Deadline: $deadline. Fundi sees reason: ${d['adminReason']}\nHe has 24h to accept redo. Do NOT mention 50% deduction in his message.',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ),
                    ),
                    if (overdue && redoOffer?['reminderSent'] != true) ...[
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => sendReminder(d),
                        child: Text('24h passed - Send 6h reminder'),
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
                        onPressed: () {
                          applyDeductionAfterNoResponse(d);
                        },
                        child: Text(
                          '30h passed - Apply 50% Deduction (Fundi no response)',
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
