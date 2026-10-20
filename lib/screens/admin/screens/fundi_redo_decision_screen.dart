import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundiRedoDecisionScreen extends StatelessWidget {
  final String disputeId;
  const FundiRedoDecisionScreen({super.key, required this.disputeId});

  Future<void> acceptRedo(BuildContext context, Map d) async {
    await FirebaseFirestore.instance
        .collection('disputes')
        .doc(disputeId)
        .update({
          'redoOffer.decision': 'accepted',
          'redoOffer.decidedAt': FieldValue.serverTimestamp(),
          'fundiAcceptedRedo': true,
          'status': 'accepted_redo',
        });
    await FirebaseFirestore.instance.collection('jobs').doc(d['jobId']).update({
      'status': 'pending_redo',
      'redoAccepted': true,
    });
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> declineRedo(BuildContext context, Map d) async {
    await FirebaseFirestore.instance.collection('disputes').doc(disputeId).update({
      'redoOffer.decision': 'declined',
      'redoOffer.decidedAt': FieldValue.serverTimestamp(),
      'fundiDeclinedRedo': true,
      'status':
          'resolved_client_win_fundi_declined_redo', // will then go to deduction after admin confirms
    });
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .doc(disputeId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        var d = snap.data!.data() as Map<String, dynamic>;
        var offer = d['redoOffer'] as Map?;
        DateTime? deadline = (offer?['deadline'] as Timestamp?)?.toDate();
        DateTime? extDeadline = (offer?['extendedDeadline'] as Timestamp?)
            ?.toDate();
        bool isReminder = offer?['reminderSent'] == true;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Redo Request - Job ${d['jobTitle']}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReminder)
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'REMINDER: You have 6 hours extra to respond. Deadline: $extDeadline',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                Text(
                  'Dispute resolved in client favour',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Reason from admin:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      d['adminReason'] ??
                          'Client evidence shows same problem within 14 days',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Will you redo the job for free?',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'You have until $deadline to respond. ${isReminder ? "This is your final 6 hours." : ""}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: () => acceptRedo(context, d),
                    child: Text(
                      'YES - I will redo for free',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => declineRedo(context, d),
                    child: Text('No - I will not redo'),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'If you redo, NO strike and NO deduction. If you decline or ignore after 24h + 6h, dispute will be treated as you will not redo.',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
