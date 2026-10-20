import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DisputeService {
  static Future<void> showFundiDisputeDialog(
    BuildContext context, {
    required String jobId,
    required Map<String, dynamic> jobData,
  }) async {
    String clientId =
        (jobData['customerId'] ??
                jobData['clientId'] ??
                jobData['customer_id'] ??
                '')
            .toString();
    String clientName =
        (jobData['customerName'] ?? jobData['clientName'] ?? 'Client')
            .toString();

    String type = 'client_breach';
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Raise Dispute - Job ${jobId.substring(0, 6)}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job: ${jobData['title'] ?? ''}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Client: $clientName',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: 'What happened? *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'client_breach',
                      child: Text(
                        'Client didn\'t do what was agreed',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'payment_not_received',
                      child: Text(
                        'Money released but I never received',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'extra_work',
                      child: Text(
                        'Client asked extra outside scope',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'no_access',
                      child: Text(
                        'Client denied site access',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'abuse',
                      child: Text(
                        'Abuse / threat',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                  ],
                  onChanged: (v) => setSt(() => type = v!),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Explain with details *',
                    hintText: type == 'payment_not_received'
                        ? 'e.g. App showed KES 2000 released on 12 Oct but M-Pesa not received...'
                        : 'Explain what client agreed vs what happened...',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This will pause escrow and notify admin. Admin will review in Disputes tab.',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Submit Dispute',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (reasonCtrl.text.trim().length < 10) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Explain at least 10 chars')));
      return;
    }

    var uid = FirebaseAuth.instance.currentUser!.uid;
    var user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('disputes').add({
      'jobId': jobId,
      'jobTitle': jobData['title'] ?? '',
      'clientId': clientId,
      'clientName': clientName,
      'fundiId': uid,
      'fundiName':
          user?.displayName ?? (jobData['assignedFundiName'] ?? 'Fundi'),
      'type': type,
      'reason': reasonCtrl.text.trim(),
      'reporterRole': 'fundi',
      'status': 'open',
      'escrowStatus': jobData['escrowStatus'] ?? 'unknown',
      'escrowAmount':
          jobData['escrowAmount'] ??
          jobData['agreedPrice'] ??
          jobData['systemPriceAvg'] ??
          0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'disputed',
      'disputedBy': uid,
      'disputedByRole': 'fundi',
      'disputeType': type,
      'disputedAt': FieldValue.serverTimestamp(),
      'disputeReason': reasonCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dispute for job ${jobId.substring(0, 6)} raised ✓ Admin will review',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  static Future<void> showClientDisputeDialog(
    BuildContext context, {
    required String jobId,
    required Map<String, dynamic> jobData,
  }) async {
    String fundiId = (jobData['assignedFundiId'] ?? jobData['fundiId'] ?? '')
        .toString();
    String fundiName =
        (jobData['assignedFundiName'] ?? jobData['fundiName'] ?? 'Fundi')
            .toString();
    String type = 'fundi_no_show';
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Raise Dispute - Job ${jobId.substring(0, 6)}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Job: ${jobData['title'] ?? ''}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Fundi: $fundiName',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: 'What happened? *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'fundi_no_show',
                      child: Text(
                        'Fundi didn\'t show up',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'poor_work',
                      child: Text(
                        'Poor work / not as agreed',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'overcharge',
                      child: Text(
                        'Asked for more money outside app',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'fundi_breach',
                      child: Text(
                        'Fundi didn\'t do what was agreed',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'abuse',
                      child: Text(
                        'Abuse / threat',
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                  ],
                  onChanged: (v) => setSt(() => type = v!),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Explain with details *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Submit Dispute',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (reasonCtrl.text.trim().length < 10) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Explain at least 10 chars')));
      return;
    }
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('disputes').add({
      'jobId': jobId,
      'jobTitle': jobData['title'] ?? '',
      'clientId': uid,
      'clientName': user?.displayName ?? (jobData['customerName'] ?? 'Client'),
      'fundiId': fundiId,
      'fundiName': fundiName,
      'type': type,
      'reason': reasonCtrl.text.trim(),
      'reporterRole': 'client',
      'status': 'open',
      'escrowStatus': jobData['escrowStatus'] ?? 'unknown',
      'escrowAmount': jobData['escrowAmount'] ?? jobData['agreedPrice'] ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'disputed',
      'disputedBy': uid,
      'disputedByRole': 'client',
      'disputeType': type,
      'disputedAt': FieldValue.serverTimestamp(),
      'disputeReason': reasonCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispute raised ✓ Admin will review'),
          backgroundColor: Colors.green.shade700,
        ),
      );
  }
}
