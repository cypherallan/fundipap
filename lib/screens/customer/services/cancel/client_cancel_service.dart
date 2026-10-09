import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';

class ClientCancelService {
  static const double feeRate = 0.05;
  static List<String> clientReasons = [
    'Fundi late / not arriving',
    'Found another fundi',
    'Budget changed',
    'Job no longer needed',
    'Safety / trust concerns',
    'Other',
  ];

  static bool _isFundiPriceRequestPending(Map<String, dynamic> job) {
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    if (reneg == null) return false;
    var requested = reneg['requested'] == true;
    var status = (reneg['status'] ?? '').toString().toLowerCase();
    var requestedBy = (reneg['requestedBy'] ?? '').toString().toLowerCase();
    if (requested && status == 'pending' && requestedBy != 'client')
      return true;
    if (status == 'pending' && requestedBy == 'fundi') return true;
    return requested && status == 'pending';
  }

  static Future<void> showCancelDialog({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
  }) async {
    String status = (job['status'] ?? '').toString().toLowerCase();
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

    if (isStarted) {
      await _showBlocked(
        context,
        'Cannot cancel',
        'Fundi already started the job. Use dispute if issue.',
      );
      return;
    }

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

    String reason = clientReasons[0];
    final otherCtrl = TextEditingController();

    if (!escrowLocked) {
      bool? ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
            'Remove this fundi?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          content: Text(
            'You have NOT locked money to escrow yet. This fundi will be removed and job goes back to OPEN for other fundis. No fee.',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Keep Fundi'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Yes, Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await _performCancel(
        context: context,
        jobId: jobId,
        job: job,
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

    int platformFee, clientRefund, fundiGets;
    if (!effectiveArrived) {
      platformFee = (labourForCalc * feeRate).round();
      clientRefund = labourForCalc + transport;
      fundiGets = 0;
    } else {
      platformFee = (labourForCalc * feeRate).round();
      clientRefund = (labourForCalc * 0.95).round();
      fundiGets = transport;
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
            effectiveArrived
                ? 'Cancel after site visit?'
                : 'Cancel before fundi travels?',
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
                  padding: EdgeInsets.all(12),
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
                      SizedBox(height: 8),
                      _row('Labour (locked):', 'KES $labourForCalc'),
                      _row('Transport:', 'KES $transport'),
                      _row('Total locked:', 'KES $totalLocked', bold: true),
                      Divider(),
                      Container(
                        padding: EdgeInsets.all(8),
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
                  items: clientReasons
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
                await _performCancel(
                  context: context,
                  jobId: jobId,
                  job: job,
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
              child: Text('Yes, Cancel - Lose KES $platformFee'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _performCancel({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
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

      if (!escrowWasLocked) {
        await db.collection('jobs').doc(jobId).update({
          'status': 'open',
          'cancelled': false,
          'autoCancelled': false,
          'cancelledBy': 'client',
          'cancelledById': uid,
          'cancelReason': reason,
          'cancelDetails': details,
          'assignedFundiId': FieldValue.delete(),
          'assignedFundi': FieldValue.delete(),
          'assignedFundiName': FieldValue.delete(),
          'fundiId': FieldValue.delete(),
          'escrowStatus': 'pending',
          'lastClientCancelForFundi': fundiId,
          'lastCancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (fundiId.isNotEmpty) {
          await db
              .collection('jobs')
              .doc(jobId)
              .collection('bids')
              .doc(fundiId)
              .set({
                'status': 'cancelled_by_client',
                'cancelled': true,
                'cancelledBy': 'client',
                'cancelledAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
        await db.collection('cancellationLogs').add({
          'jobId': jobId,
          'fundiId': fundiId,
          'clientId': clientId,
          'cancelledBy': 'client',
          'arrived': arrived,
          'wasPriceRequestPending': wasPriceRequestPending,
          'labour': labour,
          'transport': transport,
          'platformFee': 0,
          'reason': reason,
          'details': details,
          'escrowWasLocked': false,
          'reopened': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (fundiId.isNotEmpty) {
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
                'cancelledBy': 'client',
                'transportPayout': 0,
                'reopened': true,
                'cancelledAt': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cancelled for this fundi. Job moved back to open for others.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
        }
        return;
      }

      await db.collection('jobs').doc(jobId).update({
        'status': arrived ? 'cancelled_after_arrival' : 'cancelled',
        'cancelled': true,
        'cancelledBy': 'client',
        'cancelledById': uid,
        'cancelReason': reason,
        'cancelDetails': details,
        'platformFee': platformFee,
        'clientRefund': clientRefund,
        'fundiPayout': fundiGets,
        'transportFeeStatus': fundiGets > 0 ? 'released' : 'refunded',
        'escrowStatus': 'refunded',
        'wasPriceRequestPending': wasPriceRequestPending,
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
        'cancelledBy': 'client',
        'arrived': arrived,
        'wasPriceRequestPending': wasPriceRequestPending,
        'refundReason': wasPriceRequestPending
            ? 'Client cancel after fundi price request pending - uses old escrow $total'
            : 'Client cancel - 5% on labour only',
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
        'cancelledBy': 'client',
        'arrived': arrived,
        'wasPriceRequestPending': wasPriceRequestPending,
        'labour': labour,
        'transport': transport,
        'platformFee': platformFee,
        'reason': reason,
        'details': details,
        'escrowWasLocked': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (fundiId.isNotEmpty) {
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
              'cancelledBy': 'client',
              'transportPayout': fundiGets,
              'cancelledAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cancelled. You get KES $clientRefund, fee KES $platformFee',
            ),
            backgroundColor: Colors.green,
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

  static Widget _row(String l, String r, {bool bold = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
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
