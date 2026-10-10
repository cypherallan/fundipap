import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../services/fundi_penalty_service.dart';
import '../../../../services/fundi_badge_service.dart';

class FundiCancelService {
  static const double feeRate = 0.05;
  static List<String> fundiReasons = [
    'Client not available',
    'Client refused escrow',
    'Job misleading / more work',
    'Safety concerns',
    'No materials / client did not buy',
    'Other',
  ];

  static bool _isOpenStatus(String s) {
    s = s.toLowerCase();
    return [
          'open',
          'bidding',
          'pending',
          'searching',
          'new',
          'negotiating',
          'countered',
          'counter_pending',
          'pending_client_accept',
          'counter_pending_client',
          'bid_pending',
          'offer_pending',
        ].contains(s) ||
        s.contains('counter') ||
        s.contains('negotiat');
  }

  static bool _canFundiCancel(Map<String, dynamic> job) {
    String status = (job['status'] ?? '').toString().toLowerCase();
    if (_isOpenStatus(status)) return true;
    bool travelling =
        job['travelling'] == true ||
        status == 'travelling' ||
        job['siteVisitStarted'] == true;
    bool siteDone =
        job['siteVisitDone'] == true ||
        job['siteVisited'] == true ||
        job['fundiArrivedAt'] != null;
    bool started =
        [
          'in_progress',
          'pending_completion',
          'job_completed',
          'completed',
        ].contains(status) ||
        job['workStartedAt'] != null;
    if (started) return false;
    if (travelling || siteDone) return false;
    return ['assigned', 'confirmed', 'escrow_held'].contains(status);
  }

  static bool _isFundiPriceRequestPending(Map<String, dynamic> job) {
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    if (reneg == null) return false;
    return reneg['requested'] == true &&
        (reneg['status'] ?? '').toString().toLowerCase() == 'pending';
  }

  static Future<void> showCancelDialog({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
  }) async {
    String status = (job['status'] ?? '').toString().toLowerCase();
    if (_isOpenStatus(status)) {
      String reason = fundiReasons[0];
      final otherCtrl = TextEditingController();
      bool? ok = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (ctx, setSt) => AlertDialog(
            title: Text(
              'Cancel this bid?',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You will withdraw your bid. Job stays open for other fundis.',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  items: fundiReasons
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
                SizedBox(height: 8),
                TextField(
                  controller: otherCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: reason == 'Other'
                        ? 'Explain *'
                        : 'Details (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Keep Bid'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (reason == 'Other' && otherCtrl.text.trim().length < 5) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Explain reason min 5 chars')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: Text('Yes, Cancel Bid'),
              ),
            ],
          ),
        ),
      );
      if (ok != true) return;
      await _performFundiWithdraw(
        context: context,
        jobId: jobId,
        reason: reason,
        details: otherCtrl.text.trim(),
      );
      return;
    }
    bool isStarted = [
      'in_progress',
      'pending_completion',
      'job_completed',
    ].contains(status);
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

    String reason = fundiReasons[0];
    final otherCtrl = TextEditingController();
    int escrowAmount = _toInt(job['escrowAmount'] ?? 0);
    bool priceRequestPending = _isFundiPriceRequestPending(job);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Cancel this job?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are cancelling before site visit. No payment will be released to you. Full escrow will be refunded to client.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Why are you cancelling? *',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: reason,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: fundiReasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r, style: GoogleFonts.inter(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setSt(() => reason = v!),
              ),
              SizedBox(height: 8),
              TextField(
                controller: otherCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: reason == 'Other'
                      ? 'Explain *'
                      : 'Details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Keep Job'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (reason == 'Other' && otherCtrl.text.trim().length < 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Explain reason min 5 chars')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _performCancelAfterEscrow(
                  context: context,
                  jobId: jobId,
                  job: job,
                  reason: reason,
                  details: otherCtrl.text.trim(),
                  total: escrowAmount,
                  wasPriceRequestPending: priceRequestPending,
                );
              },
              child: Text('Yes, Cancel Job'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _performFundiWithdraw({
    required BuildContext context,
    required String jobId,
    required String reason,
    required String details,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      var jobDoc = await db.collection('jobs').doc(jobId).get();
      var jobData = jobDoc.data() ?? {};
      final bids = await db
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .where('fundiId', isEqualTo: uid)
          .get();
      for (var b in bids.docs) {
        await b.reference.update({
          'deletedForFundi': true,
          'status': 'withdrawn',
          'cancelReason': reason,
          'cancelDetails': details,
          'withdrawnAt': FieldValue.serverTimestamp(),
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await db
          .collection('fundis')
          .doc(uid)
          .collection('cancelledJobs')
          .doc(jobId)
          .set({
            'jobId': jobId,
            'title': jobData['title'] ?? 'Job',
            'clientName':
                jobData['customerName'] ?? jobData['clientName'] ?? 'Client',
            'cancelReason': reason,
            'cancelDetails': details,
            'type': 'withdrawn',
            'cancelledAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          });
      await FundiPenaltyService.onFundiCancel(
        fundiId: uid,
        jobId: jobId,
        reason: reason,
      );
      await FundiBadgeService.recalcAndUpdate(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bid cancelled - moved to cancelled tab'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  static Future<void> _performCancelAfterEscrow({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
    required String reason,
    required String details,
    required int total,
    bool wasPriceRequestPending = false,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String clientId = (job['customerId'] ?? job['clientId'] ?? '').toString();
      await db.collection('jobs').doc(jobId).update({
        'status': 'cancelled',
        'cancelled': true,
        'cancelledBy': 'fundi',
        'cancelledById': uid,
        'cancelReason': reason,
        'cancelDetails': details,
        'platformFee': 0,
        'clientRefund': total,
        'fundiPayout': 0,
        'escrowStatus': 'refunded',
        'wasPriceRequestPending': wasPriceRequestPending,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await db.collection('cancellationLogs').add({
        'jobId': jobId,
        'fundiId': uid,
        'clientId': clientId,
        'cancelledBy': 'fundi',
        'reason': reason,
        'details': details,
        'escrowWasLocked': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await db
          .collection('fundis')
          .doc(uid)
          .collection('cancelledJobs')
          .doc(jobId)
          .set({
            'jobId': jobId,
            'title': job['title'] ?? 'Job',
            'clientName': job['customerName'] ?? job['clientName'] ?? 'Client',
            'cancelReason': reason,
            'type': 'assigned_cancelled',
            'cancelledBy': 'fundi',
            'transportPayout': 0,
            'cancelledAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await FundiPenaltyService.onFundiCancel(
        fundiId: uid,
        jobId: jobId,
        reason: reason,
      );
      await FundiBadgeService.recalcAndUpdate(uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancelled. Client refunded KES $total'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
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
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
