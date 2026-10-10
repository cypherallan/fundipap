import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../app.dart';
import 'client_cancel_calculator.dart';

class ClientCancelService {
  static List<String> clientReasons = [
    'Fundi late / not arriving',
    'Found another fundi',
    'Budget changed',
    'Job no longer needed',
    'Safety / trust concerns',
    'Other',
  ];

  static Future<void> showCancelDialog({
    required BuildContext context,
    required String jobId,
    required Map<String, dynamic> job,
  }) async {
    // --- SINGLE SOURCE OF TRUTH ---
    final calc = ClientCancelCalculator.calculate(job);

    // debug - see exactly what goes wrong
    for (var l in calc.logs) {
      if (kDebugMode) debugPrint('[CANCEL_AUDIT] $l');
    }

    if (calc.stage == ClientCancelStage.blockedJobStarted) {
      await _showBlocked(
        context,
        'Cannot cancel',
        'Fundi already started the job. Use dispute if issue.',
      );
      return;
    }

    bool effectiveArrived = calc.arrived || calc.priceRequestPending;

    // CANCEL 1: BEFORE ESCROW
    if (calc.stage == ClientCancelStage.beforeEscrow) {
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
        labour: calc.labourForCalc,
        transport: calc.transport,
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

    // CANCEL 2-6: WITH ESCROW LOCKED
    int labourForCalc = calc.labourForCalc;
    int transport = calc.transport;
    int totalLocked = calc.totalLockedDisplay;
    int platformFee = calc.feeForCalc;
    int fundiGets = calc.fundiGets;
    int clientRefund = calc.clientRefund;

    String reason = clientReasons[0];
    final otherCtrl = TextEditingController();

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
                      if (calc.stage ==
                              ClientCancelStage.clientCounterAcceptedNotPaid ||
                          calc.stage == ClientCancelStage.fundiRequestPending)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Note: Extra KES ${calc.extraLabour} requested but not yet paid. Showing OLD locked only.',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                  wasPriceRequestPending: calc.priceRequestPending,
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
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeNavigator(
                role: 'client',
                email: FirebaseAuth.instance.currentUser?.email ?? '',
                initialIndex: 0,
              ),
            ),
            (r) => false,
          );
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
        'refundReason': 'Client cancel - 5% on labour only',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (fundiGets > 0 && fundiId.isNotEmpty) {
        await db.collection('transportTransactions').doc(jobId).set({
          'jobId': jobId,
          'fundiId': fundiId,
          'amount': fundiGets,
          'status': 'released',
          'message':
              'You have received KES $fundiGets as your transport due to client cancelling after you started site visit. Confirm you received',
          'releasedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Fundi notification - this is what fundi sees
        await db.collection('notifications').add({
          'userId': fundiId,
          'jobId': jobId,
          'type': 'transport_released',
          'title': 'Transport released',
          'message':
              'You have received KES $fundiGets as your transport due to client cancelling after you started site visit. Confirm you received',
          'requiresConfirmation': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
              'transportMessage':
                  'You have received KES $fundiGets as your transport due to client cancelling after you started site visit. Confirm you received',
              'requiresConfirmation': fundiGets > 0,
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
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeNavigator(
              role: 'client',
              email: FirebaseAuth.instance.currentUser?.email ?? '',
              initialIndex: 1,
              initialJobStatusTab: 3,
            ),
          ),
          (r) => false,
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
}
