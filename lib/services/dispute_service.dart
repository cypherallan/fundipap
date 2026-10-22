import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/disputes/upload_evidence_screen.dart';

class DisputeService {
  static Future<String> _getMyBadge(String uid) async {
    var f = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(uid)
        .get();
    if (f.exists) {
      var m = f.data() as Map;
      return (m['badge'] ?? m['subscriptionBadge'] ?? 'none').toString();
    }
    var c = await FirebaseFirestore.instance
        .collection('clients')
        .doc(uid)
        .get();
    if (c.exists) {
      var m = c.data() as Map;
      return (m['badge'] ?? 'none').toString();
    }
    return 'none';
  }

  // ---- EVIDENCE CONFIG - DYNAMIC PER TYPE ----
  static Map<String, dynamic> getEvidenceConfig(String type) {
    const configs = {
      // FUNDI vs CLIENT (10)
      'payment_not_received': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': true,
        'hint':
            'Upload M-Pesa statement PDF/screenshot showing no receipt. Add Transaction ID.',
      },
      'extra_work': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint':
            'Describe extra work client asked outside agreed scope. No photo needed unless you did it.',
      },
      'no_materials': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint': 'What materials did client promise but didn\'t provide?',
      },
      'no_access': {
        'requiresPhoto': true,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint': 'If possible, photo of closed gate / site. Optional.',
      },
      'client_no_show': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint': 'No photo needed. System will check your arrival time.',
      },
      'cancelled_after_arrival': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': true,
        'hint': 'Upload transport receipt / boda receipt if you have.',
      },
      'payment_delay': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint': 'No evidence needed. Admin will check job status.',
      },
      'unsafe_conditions': {
        'requiresPhoto': true,
        'requiresVideo': true,
        'requiresDoc': false,
        'hint': 'Photo/video of unsafe site - exposed wires, flooded, etc.',
      },
      'false_accusation': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint': 'Upload chat screenshot where client threatened bad review.',
      },
      'abuse': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint':
            'No photo needed. Describe what was said/done, time and place. Chat screenshot if available.',
      },
      // CLIENT vs FUNDI (6 - your list)
      'unprofessional_work': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint':
            'Describe behavior. No photo needed, but chat screenshot helps.',
      },
      'damaged_property': {
        'requiresPhoto': true,
        'requiresVideo': true,
        'requiresDoc': false,
        'hint': 'Upload before/after photos and video showing damage.',
      },
      'repeat_job': {
        'requiresPhoto': true,
        'requiresVideo': true,
        'requiresDoc': false,
        'hint':
            'Upload video testing the fault - e.g., plug device in socket to show it still not working. Include previous job date.',
      },
      'missing_items': {
        'requiresPhoto': true,
        'requiresVideo': false,
        'requiresDoc': false,
        'hint': 'Photo of area where item was, and list of missing item.',
      },
      'incomplete_work': {
        'requiresPhoto': true,
        'requiresVideo': true,
        'requiresDoc': false,
        'hint': 'Photos showing what was left incomplete vs what was agreed.',
      },
      'extra_outside_app': {
        'requiresPhoto': false,
        'requiresVideo': false,
        'requiresDoc': true,
        'hint':
            'Upload M-Pesa request or chat where fundi asked for extra money outside app.',
      },
    };
    return configs[type] ??
        {
          'requiresPhoto': false,
          'requiresVideo': false,
          'requiresDoc': false,
          'hint': 'Describe with details.',
        };
  }

  static Future<void> showFundiDisputeDialog(
    BuildContext context, {
    required String jobId,
    required Map<String, dynamic> jobData,
  }) async {
    String clientId = (jobData['customerId'] ?? jobData['clientId'] ?? '')
        .toString();
    String clientName =
        (jobData['customerName'] ?? jobData['clientName'] ?? 'Client')
            .toString();

    String type = 'payment_not_received';
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final cfg = getEvidenceConfig(type);
          return AlertDialog(
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
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
                        value: 'payment_not_received',
                        child: Text(
                          'Money released but M-Pesa not received',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'extra_work',
                        child: Text(
                          'Client asked extra / changed scope',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'no_materials',
                        child: Text(
                          'Client didn\'t provide materials as promised',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'no_access',
                        child: Text(
                          'Denied access to work site',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'client_no_show',
                        child: Text(
                          'Client not available at agreed time',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled_after_arrival',
                        child: Text(
                          'Cancelled after I arrived - transport loss',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'payment_delay',
                        child: Text(
                          'Work done but delaying to mark complete',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'unsafe_conditions',
                        child: Text(
                          'Unsafe work conditions',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'false_accusation',
                        child: Text(
                          'False accusation / blackmail',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'abuse',
                        child: Text(
                          'Abuse / threat / harassment',
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
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Evidence needed: ${cfg['hint']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'After submit, both you and client will be asked to upload evidence. Only what is relevant for this type.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black45,
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
                  backgroundColor: Colors.orange.shade800,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Submit Dispute',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
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
    var badge = await _getMyBadge(uid);
    var cfg = getEvidenceConfig(type);

    var docRef = await FirebaseFirestore.instance.collection('disputes').add({
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
      'reportedBy': uid,
      'reporterBadge': badge,
      'status': 'open',
      'evidenceStatus': 'awaiting_both',
      'evidenceConfig': cfg,
      'reporterEvidenceSubmitted': false,
      'reportedEvidenceSubmitted': false,
      'evidenceDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(hours: 48)),
      ),
      'escrowStatus': jobData['escrowStatus'] ?? 'unknown',
      'escrowAmount': jobData['escrowAmount'] ?? jobData['agreedPrice'] ?? 0,
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
          content: Text('Dispute raised ✓ Upload evidence now'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadEvidenceScreen(disputeId: docRef.id),
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
    String type = 'unprofessional_work';
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) {
          final cfg = getEvidenceConfig(type);
          return AlertDialog(
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
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
                        value: 'unprofessional_work',
                        child: Text(
                          'Unprofessional work',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'damaged_property',
                        child: Text(
                          'Damaged property',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'repeat_job',
                        child: Text(
                          'Same problem reoccured',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'missing_items',
                        child: Text(
                          'Missing items',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'incomplete_work',
                        child: Text(
                          'Incomplete work',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'extra_outside_app',
                        child: Text(
                          'Asked for more outside app',
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
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Evidence needed: ${cfg['hint']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
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
          );
        },
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
    var badge = await _getMyBadge(uid);
    var cfg = getEvidenceConfig(type);

    var docRef = await FirebaseFirestore.instance.collection('disputes').add({
      'jobId': jobId,
      'jobTitle': jobData['title'] ?? '',
      'clientId': uid,
      'clientName': user?.displayName ?? (jobData['customerName'] ?? 'Client'),
      'fundiId': fundiId,
      'fundiName': fundiName,
      'type': type,
      'reason': reasonCtrl.text.trim(),
      'reporterRole': 'client',
      'reportedBy': uid,
      'reporterBadge': badge,
      'status': 'open',
      'evidenceStatus': 'awaiting_both',
      'evidenceConfig': cfg,
      'reporterEvidenceSubmitted': false,
      'reportedEvidenceSubmitted': false,
      'evidenceDeadline': Timestamp.fromDate(
        DateTime.now().add(Duration(hours: 48)),
      ),
      'escrowStatus': jobData['escrowStatus'] ?? 'unknown',
      'escrowAmount':
          jobData['escrowAmount'] ??
          jobData['totalClientPays'] ??
          jobData['totalCost'] ??
          jobData['lastCounterAmount'] ??
          jobData['laborCost'] ??
          jobData['agreedPrice'] ??
          jobData['acceptedBidAmount'] ??
          0,
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dispute raised ✓ Upload evidence now'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadEvidenceScreen(disputeId: docRef.id),
        ),
      );
    }
  }
}
