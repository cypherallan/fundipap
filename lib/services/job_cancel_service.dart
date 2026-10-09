import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'fundi_penalty_service.dart';
import 'fundi_badge_service.dart';

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

  static bool _isOpenStatus(String status) {
    final s = status.toLowerCase();
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
    // OPEN / NEGOTIATING / COUNTERED - fundi can always withdraw his bid before escrow
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
    var requested = reneg['requested'] == true;
    var status = (reneg['status'] ?? '').toString().toLowerCase();
    var requestedBy = (reneg['requestedBy'] ?? '').toString().toLowerCase();
    if (requested && status == 'pending' && requestedBy != 'client')
      return true;
    if (status == 'pending' && requestedBy == 'fundi') return true;
    if (requested && status == 'pending') return true;
    return false;
  }

  static Future<void> showCancelDialog({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
    required bool isClient,
  }) async {
    String status = (job['status'] ?? '').toString().toLowerCase();

    // FUNDI withdrawing from OPEN job - no escrow, just remove his bid
    if (!isClient && _isOpenStatus(status)) {
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration: const InputDecoration(
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Bid'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  if (reason == 'Other' && otherCtrl.text.trim().length < 5) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Explain reason min 5 chars'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Yes, Cancel Bid'),
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
    bool priceRequestPending = _isFundiPriceRequestPending(job);
    bool effectiveArrived = arrived || priceRequestPending;

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

    int oldLabour = _toInt(
      job['currentLabour'] ??
          job['agreedPrice'] ??
          job['acceptedBidAmount'] ??
          job['fundiBidAmount'] ??
          job['budget'] ??
          0,
    );
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    if (reneg != null && reneg['oldLabor'] != null)
      oldLabour = _toInt(reneg['oldLabor']);
    int newLabour = oldLabour;
    if (reneg != null && reneg['newLaborTotal'] != null)
      newLabour = _toInt(reneg['newLaborTotal']);
    int transport = _toInt(job['transportFee'] ?? job['escrowTransport'] ?? 0);
    int escrowAmount = _toInt(job['escrowAmount'] ?? 0);
    int totalLocked = escrowAmount > 0
        ? escrowAmount
        : (oldLabour + transport + (oldLabour * feeRate).round());
    int newTotalExpected =
        newLabour + transport + (newLabour * feeRate).round();
    bool extraLocked =
        escrowAmount >= newTotalExpected && newLabour != oldLabour;
    int labourForCalc = oldLabour;
    if (priceRequestPending) {
      labourForCalc = extraLocked ? newLabour : oldLabour;
    } else {
      labourForCalc =
          (reneg != null &&
              reneg['newLaborTotal'] != null &&
              !priceRequestPending)
          ? newLabour
          : oldLabour;
      if (reneg != null &&
          (reneg['status'] ?? '').toString().contains('accepted'))
        labourForCalc = newLabour;
    }

    String escrowStatusStr = (job['escrowStatus'] ?? '').toString();
    bool escrowLocked =
        escrowAmount > 0 ||
        escrowStatusStr == 'held' ||
        escrowStatusStr == 'locked' ||
        job['escrowDone'] == true;

    if (!escrowLocked) {
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
      if (ok != true) return;
      await _performCancel(
        context: context,
        jobId: jobId,
        job: job,
        isClient: isClient,
        arrived: false,
        labour: labourForCalc,
        transport: transport,
        total: 0,
        platformFee: 0,
        clientRefund: 0,
        fundiGets: 0,
        reason: 'Cancelled before escrow',
        details: 'No money locked yet - no fee',
        escrowWasLocked: false,
        wasPriceRequestPending: false,
      );
      return;
    }

    late int platformFee, clientRefund, fundiGets;
    if (isClient) {
      if (!effectiveArrived) {
        platformFee = (labourForCalc * feeRate).round();
        clientRefund = labourForCalc + transport;
        fundiGets = 0;
      } else {
        platformFee = (labourForCalc * feeRate).round();
        clientRefund = (labourForCalc * 0.95).round();
        fundiGets = transport;
      }
    } else {
      platformFee = 0;
      clientRefund = totalLocked;
      fundiGets = 0;
    }
    if (clientRefund + fundiGets > totalLocked) {
      clientRefund = totalLocked - fundiGets;
      if (clientRefund < 0) clientRefund = 0;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            isClient
                ? (effectiveArrived
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
                if (isClient)
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
                        _row('Labour (locked):', 'KES $labourForCalc'),
                        if (priceRequestPending &&
                            !extraLocked &&
                            newLabour != oldLabour)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Fundi requested new labour KES $newLabour (not yet locked)',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        _row('Transport:', 'KES $transport'),
                        _row('Total locked:', 'KES $totalLocked', bold: true),
                        const Divider(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: FundipapColors.primaryYellow.withOpacity(
                              0.15,
                            ),
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
                                'You get back:',
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
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
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
                        const SizedBox(width: 8),
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
                  arrived: effectiveArrived,
                  labour: labourForCalc,
                  transport: transport,
                  total: totalLocked,
                  platformFee: platformFee,
                  clientRefund: clientRefund,
                  fundiGets: fundiGets,
                  reason: reason,
                  details: otherCtrl.text.trim(),
                  escrowWasLocked: true,
                  wasPriceRequestPending: priceRequestPending,
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

  // NEW: fundi withdraws bid for OPEN job - only for him
  static Future<void> _performFundiWithdraw({
    required BuildContext context,
    required String jobId,
    required String reason,
    required String details,
  }) async {
    try {
      final db = FirebaseFirestore.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Get job title for cancelled collection
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

      // NEW: Add to fundi's cancelledJobs like notifications/reviews
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bid cancelled - moved to cancelled tab'),
            backgroundColor: Colors.orange,
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
    bool wasPriceRequestPending = false,
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

      // HARD FIX: don't trust param, derive from uid
      bool actualIsClient = clientId.isNotEmpty ? clientId == uid : isClient;
      bool actualIsFundi = !actualIsClient;

      await db.collection('jobs').doc(jobId).update({
        'status': arrived ? 'cancelled_after_arrival' : 'cancelled',
        'cancelled': true,
        'cancelledBy': actualIsClient ? 'client' : 'fundi',
        'cancelledById': uid,
        'cancelReason': reason,
        'cancelDetails': details,
        'platformFee': platformFee,
        'clientRefund': clientRefund,
        'fundiPayout': fundiGets,
        'transportFeeStatus': fundiGets > 0 ? 'released' : 'refunded',
        'escrowStatus': escrowWasLocked ? 'refunded' : 'pending',
        'wasPriceRequestPending': wasPriceRequestPending,
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
          'cancelledBy': actualIsClient ? 'client' : 'fundi',
          'arrived': arrived,
          'wasPriceRequestPending': wasPriceRequestPending,
          'refundReason': actualIsClient
              ? (wasPriceRequestPending
                    ? 'Client cancel after fundi price request pending - uses old escrow $total'
                    : 'Client cancel - 5% on labour only')
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
        'cancelledBy': actualIsClient ? 'client' : 'fundi',
        'arrived': arrived,
        'wasPriceRequestPending': wasPriceRequestPending,
        'labour': labour,
        'transport': transport,
        'platformFee': platformFee,
        'reason': reason,
        'details': details,
        'escrowWasLocked': escrowWasLocked,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // save to fundi cancelledJobs subcollection like notifications
      if (fundiId.isNotEmpty) {
        try {
          await db
              .collection('fundis')
              .doc(fundiId)
              .collection('cancelledJobs')
              .doc(jobId)
              .set({
                'jobId': jobId,
                'title': job['title'] ?? 'Job',
                'clientName':
                    job['customerName'] ?? job['clientName'] ?? 'Client',
                'cancelReason': reason,
                'type': 'assigned_cancelled',
                'cancelledBy': actualIsClient ? 'client' : 'fundi',
                'transportPayout': fundiGets,
                'cancelledAt': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (actualIsFundi && fundiId.isNotEmpty) {
        await FundiPenaltyService.onFundiCancel(
          fundiId: fundiId,
          jobId: jobId,
          reason: reason,
        );
        await FundiBadgeService.recalcAndUpdate(fundiId);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              escrowWasLocked
                  ? (actualIsClient
                        ? 'Cancelled. You get KES $clientRefund, fee KES $platformFee'
                        : 'Cancelled. Client refunded KES $clientRefund')
                  : 'Job cancelled - no fee, no escrow was locked',
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

  static Future<void> checkAndAutoCancelIfExpired({
    required String jobId,
    required Map<String, dynamic> job,
  }) async {
    final startedAt =
        job['siteVisitStartedAt'] ??
        job['travellingAt'] ??
        job['startedTravellingAt'];
    if (startedAt == null) return;
    DateTime startTime;
    if (startedAt is Timestamp)
      startTime = startedAt.toDate();
    else if (startedAt is DateTime)
      startTime = startedAt;
    else
      return;
    final elapsed = DateTime.now().difference(startTime);
    bool siteDone =
        job['siteVisitDone'] == true ||
        job['siteVisited'] == true ||
        job['fundiArrivedAt'] != null;
    if (siteDone) return;
    if (elapsed.inMinutes < 150) return;
    final db = FirebaseFirestore.instance;
    int total = _toInt(job['escrowAmount'] ?? 0);
    if (total == 0) {
      int labour = _toInt(job['currentLabour'] ?? job['agreedPrice'] ?? 0);
      int transport = _toInt(job['transportFee'] ?? 0);
      total = labour + transport + (labour * feeRate).round();
    }
    await db.collection('jobs').doc(jobId).update({
      'status': 'auto_cancelled_no_arrival',
      'cancelled': true,
      'autoCancelled': true,
      'cancelledBy': 'system',
      'cancelReason': 'Fundi took too long to arrive',
      'clientRefund': total,
      'platformFee': 0,
      'fundiPayout': 0,
      'escrowStatus': 'refunded',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await db.collection('cancellationLogs').add({
      'jobId': jobId,
      'cancelledBy': 'system',
      'reason': 'No arrival within 2h30m - 20km rule',
      'clientRefund': total,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
