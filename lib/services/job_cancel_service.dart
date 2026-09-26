import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// FINAL CANCEL SERVICE - 5% only on labour, transport never charged fee
/// Rules locked with user:
/// Before travelling: client 95% labour + 100% transport, fee 5% labour, fundi 0
/// After site visit (travelling/site_visit): client 95% labour, fundi transport, fee 5% labour
/// Fundi can cancel ONLY before travelling, after travelling locked
/// After in_progress (Start Job clicked): both cannot cancel

class JobCancelService {
  static const double feeRate = 0.05;

  static List<String> clientReasons = [
    'Fundi late / not arriving',
    'Found another fundi',
    'Budget changed',
    'Job no longer needed',
    'Safety / trust concerns',
    'Other',
  ];
  static List<String> fundiReasons = [
    'Client not available',
    'Client refused escrow',
    'Job misleading / more work',
    'Safety concerns',
    'No materials / client did not buy',
    'Other',
  ];

  static bool _canFundiCancel(Map<String, dynamic> job) {
    String status = (job['status'] ?? '').toString();
    bool travelling = job['travelling'] == true || status == 'travelling';
    bool siteDone =
        job['siteVisitDone'] == true ||
        job['siteVisited'] == true ||
        job['fundiArrivedAt'] != null;
    bool started = [
      'in_progress',
      'pending_completion',
      'job_completed',
    ].contains(status);
    // Fundi can cancel only in assigned/confirmed and not travelling/siteDone/started
    if (started) return false;
    if (travelling || siteDone) return false;
    return ['assigned', 'confirmed'].contains(status);
  }

  static Future<void> showCancelDialog({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
    required bool isClient,
  }) async {
    String status = (job['status'] ?? '').toString();
    bool travelling = job['travelling'] == true || status == 'travelling';
    bool siteDone =
        job['siteVisitDone'] == true ||
        job['siteVisited'] == true ||
        job['fundiArrivedAt'] != null;
    bool isStarted = [
      'in_progress',
      'pending_completion',
      'job_completed',
    ].contains(status);
    bool arrived =
        travelling ||
        siteDone; // for refund logic: has fundi travelled/arrived?

    // Guard: Fundi locked after travelling
    if (!isClient) {
      if (isStarted) {
        await _showBlocked(
          context,
          'Cannot cancel',
          'Job already started (START JOB clicked). Must be completed. Contact support for disputes.',
        );
        return;
      }
      if (!_canFundiCancel(job)) {
        await _showBlocked(
          context,
          'Cannot cancel now',
          'You already started travelling / marked site visit. Only client can cancel now. Cancelling to get transport fee is flagged as fraud and lowers your badge.',
        );
        return;
      }
    } else {
      if (isStarted) {
        await _showBlocked(
          context,
          'Cannot cancel',
          'Fundi already started the job. Job must be completed. Use dispute if issue.',
        );
        return;
      }
    }

    String reason = isClient ? clientReasons[0] : fundiReasons[0];
    final otherCtrl = TextEditingController();

    // Parse amounts - supports both old jobs with transport and new jobs without
    int labour = _toInt(
      job['currentLabour'] ??
          job['agreedPrice'] ??
          job['acceptedBidAmount'] ??
          job['fundiBidAmount'] ??
          job['budget'] ??
          0,
    );
    // If renegotiation after price review, use new labour
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    if (reneg != null && reneg['newLaborTotal'] != null) {
      labour = _toInt(reneg['newLaborTotal']);
    }
    int transport = _toInt(job['transportFee'] ?? job['escrowTransport'] ?? 0);
    int escrowAmount = _toInt(job['escrowAmount'] ?? 0);
    int total = escrowAmount > 0 ? escrowAmount : (labour + transport);

    // Calculate with your rule: 5% ONLY on labour
    late int platformFee, clientRefund, fundiGets;
    if (isClient) {
      platformFee = (labour * feeRate).round();
      if (!arrived) {
        // Before travelling: 95% labour + 100% transport back
        clientRefund = (labour * 0.95).round() + transport;
        fundiGets = 0;
      } else {
        // After site visit: transport -> fundi, 95% labour -> client
        clientRefund = (labour * 0.95).round();
        fundiGets = transport;
      }
    } else {
      // Fundi cancel before travelling: full refund, no fee
      platformFee = 0;
      clientRefund = total;
      fundiGets = 0;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            isClient
                ? (arrived
                      ? 'Cancel after site visit?'
                      : 'Cancel before fundi travels?')
                : 'Cancel this job?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // BREAKDOWN - VISIBLE 5% ON LABOUR ONLY
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escrow Breakdown',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _row('Labour:', 'KES $labour'),
                      _row('Transport:', 'KES $transport'),
                      if (escrowAmount > 0) _row('Total locked:', 'KES $total'),
                      const Divider(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FundipapColors.primaryYellow.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _row(
                              '5% Maintenance (labour only):',
                              'KES $platformFee',
                              color: Colors.red.shade700,
                            ),
                            _row(
                              'Client gets back:',
                              'KES $clientRefund',
                              bold: true,
                              color: Colors.green.shade700,
                            ),
                            _row(
                              'Fundi gets:',
                              'KES $fundiGets',
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isClient
                            ? (arrived
                                  ? 'Fundi travelled. Transport KES $transport goes to fundi. You get 95% of labour KES ${(labour * 0.95).round()}. 5% KES $platformFee kept for app maintenance.'
                                  : 'Before travelling. You get 95% labour KES ${(labour * 0.95).round()} + 100% transport KES $transport = KES $clientRefund. 5% KES $platformFee kept for app maintenance (labour only).')
                            : 'Client gets full KES $clientRefund refund. You get 0. Will affect rating & badge.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (isClient)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'WARNING: 5% of labour (KES $platformFee) will be deducted. Transport ${arrived ? "KES $transport goes to fundi" : "100% refunded"}. Proceed?',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Why are you cancelling? *',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: reason,
                  items: (isClient ? clientReasons : fundiReasons)
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => reason = v!),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: otherCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: reason == 'Other'
                        ? 'Explain *'
                        : 'Details (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Job'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (reason == 'Other' && otherCtrl.text.trim().length < 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Explain reason min 5 chars')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _performCancel(
                  context: context,
                  jobId: jobId,
                  job: job,
                  isClient: isClient,
                  arrived: arrived,
                  labour: labour,
                  transport: transport,
                  total: total,
                  platformFee: platformFee,
                  clientRefund: clientRefund,
                  fundiGets: fundiGets,
                  reason: reason,
                  details: otherCtrl.text.trim(),
                );
              },
              child: Text(
                isClient
                    ? 'Yes, Cancel - Lose KES $platformFee'
                    : 'Yes, Cancel Job',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showBlocked(
    BuildContext context,
    String title,
    String msg,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Widget _row(String l, String r, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: GoogleFonts.inter(fontSize: 11)),
          Text(
            r,
            style: GoogleFonts.montserrat(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _performCancel({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
    required bool isClient,
    required bool arrived,
    required int labour,
    required int transport,
    required int total,
    required int platformFee,
    required int clientRefund,
    required int fundiGets,
    required String reason,
    required String details,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String fundiId =
          (job['assignedFundi'] ??
                  job['assignedFundiId'] ??
                  job['fundiId'] ??
                  '')
              .toString();
      String clientId = (job['customerId'] ?? job['clientId'] ?? '').toString();

      await db.collection('jobs').doc(jobId).update({
        'status': arrived ? 'cancelled_after_arrival' : 'cancelled',
        'cancelled': true,
        'cancelledBy': isClient ? 'client' : 'fundi',
        'cancelledById': uid,
        'cancelReason': reason,
        'cancelDetails': details,
        'platformFee': platformFee,
        'clientRefund': clientRefund,
        'fundiPayout': fundiGets,
        'transportFeeStatus': fundiGets > 0 ? 'released' : 'refunded',
        'escrowStatus': 'refunded',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('escrowTransactions').doc(jobId).set({
        'jobId': jobId,
        'labour': labour,
        'transport': transport,
        'total': total,
        'platformFee': platformFee,
        'clientRefund': clientRefund,
        'fundiGets': fundiGets,
        'cancelledBy': isClient ? 'client' : 'fundi',
        'arrived': arrived,
        'refundReason': isClient
            ? 'Client cancel - 5% on labour only'
            : 'Fundi cancel before travelling',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (fundiGets > 0 && fundiId.isNotEmpty) {
        await db.collection('transportTransactions').doc(jobId).set({
          'jobId': jobId,
          'fundiId': fundiId,
          'amount': fundiGets,
          'status': 'released',
          'releasedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await db.collection('cancellationLogs').add({
        'jobId': jobId,
        'fundiId': fundiId,
        'clientId': clientId,
        'cancelledBy': isClient ? 'client' : 'fundi',
        'arrived': arrived,
        'labour': labour,
        'transport': transport,
        'platformFee': platformFee,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!isClient && fundiId.isNotEmpty) {
        await db.collection('users').doc(fundiId).set({
          'cancellationCount': FieldValue.increment(1),
          'lastCancellationAt': FieldValue.serverTimestamp(),
          'needsRatingReview': true,
        }, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isClient
                  ? 'Cancelled. You get KES $clientRefund, fee KES $platformFee'
                  : 'Cancelled. Client refunded KES $clientRefund',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
