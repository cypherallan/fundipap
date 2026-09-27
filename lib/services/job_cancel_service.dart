import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// FINAL CANCEL SERVICE - FIXED FOR NO-ESCROW CASE
/// Rule: If money NOT locked to escrow, no figures dialog, just cancel - 0 fee

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
    bool arrived = travelling || siteDone;

    if (!isClient) {
      if (isStarted) {
        await _showBlocked(
          context,
          'Cannot cancel',
          'Job already started (START JOB clicked). Must be completed.',
        );
        return;
      }
      if (!_canFundiCancel(job)) {
        await _showBlocked(
          context,
          'Cannot cancel now',
          'You already started travelling / marked site visit. Only client can cancel now.',
        );
        return;
      }
    } else {
      if (isStarted) {
        await _showBlocked(
          context,
          'Cannot cancel',
          'Fundi already started the job. Use dispute if issue.',
        );
        return;
      }
    }

    String reason = isClient ? clientReasons[0] : fundiReasons[0];
    final otherCtrl = TextEditingController();

    int labour = _toInt(
      job['currentLabour'] ??
          job['agreedPrice'] ??
          job['acceptedBidAmount'] ??
          job['fundiBidAmount'] ??
          job['budget'] ??
          0,
    );
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    if (reneg != null && reneg['newLaborTotal'] != null) {
      labour = _toInt(reneg['newLaborTotal']);
    }
    int transport = _toInt(job['transportFee'] ?? job['escrowTransport'] ?? 0);
    int escrowAmount = _toInt(job['escrowAmount'] ?? 0);
    int total = escrowAmount > 0 ? escrowAmount : (labour + transport);

    // --- NEW FIX: If no money locked, just cancel, no figures ---
    String escrowStatusStr = (job['escrowStatus'] ?? '').toString();
    bool escrowLocked =
        escrowAmount > 0 ||
        escrowStatusStr == 'held' ||
        escrowStatusStr == 'locked' ||
        job['escrowDone'] == true;

    if (!escrowLocked) {
      // No money locked - just ask "are you sure?" no fee math
      bool? ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            'Cancel this job?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel this job? No money has been locked to escrow yet, so there is no fee.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No, Keep Job'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, Cancel Job'),
            ),
          ],
        ),
      );

      if (ok != true) return; // user said no

      await _performCancel(
        context: context,
        jobId: jobId,
        job: job,
        isClient: isClient,
        arrived: false,
        labour: labour,
        transport: transport,
        total: 0,
        platformFee: 0,
        clientRefund: 0,
        fundiGets: 0,
        reason: 'Cancelled before escrow',
        details: 'No money locked yet - no fee',
        escrowWasLocked: false,
      );
      return;
    }

    // --- Escrow IS locked, show normal money dialog ---
    late int platformFee, clientRefund, fundiGets;
    if (isClient) {
      platformFee = (labour * feeRate).round();
      if (!arrived) {
        clientRefund = (labour * 0.95).round() + transport;
        fundiGets = 0;
      } else {
        clientRefund = (labour * 0.95).round();
        fundiGets = transport;
      }
    } else {
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
                      _row('Total locked:', 'KES $total'),
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
                              'App maintenance (5% labour):',
                              'KES $platformFee',
                              color: Colors.red.shade700,
                              bold: true,
                            ),
                            _row(
                              isClient
                                  ? (arrived
                                        ? 'You get back:'
                                        : 'You get back:')
                                  : 'Client gets back:',
                              'KES $clientRefund',
                              color: Colors.green.shade700,
                              bold: true,
                            ),
                            if (fundiGets > 0)
                              _row(
                                'Fundi gets (transport):',
                                'KES $fundiGets',
                                color: Colors.blue.shade700,
                                bold: true,
                              ),
                          ],
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
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: (isClient ? clientReasons : fundiReasons)
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(
                            r,
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSt(() => reason = v!),
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
                  escrowWasLocked: true,
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
    bool escrowWasLocked = true,
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
        'escrowStatus': escrowWasLocked ? 'refunded' : 'pending',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (escrowWasLocked) {
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
      }

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
        'escrowWasLocked': escrowWasLocked,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!isClient && fundiId.isNotEmpty) {
        await db.collection('users').doc(fundiId).set({
          'cancellationCount': FieldValue.increment(1),
          'lastCancellationAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              escrowWasLocked
                  ? (isClient
                        ? 'Cancelled. You get KES $clientRefund, fee KES $platformFee'
                        : 'Cancelled. Client refunded KES $clientRefund')
                  : 'Job cancelled - no fee, no escrow was locked',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // DO NOT POP HERE - let the StreamBuilder show the cancelled card
        // User will press back arrow once to go to Cancelled tab
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
