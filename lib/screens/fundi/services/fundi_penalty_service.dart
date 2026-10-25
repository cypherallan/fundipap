import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class FundiPenaltyService {
  static const Duration suspend24h = Duration(hours: 24);
  static const Duration suspend7d = Duration(days: 7);
  static const Duration suspend30d = Duration(days: 30);

  static Future<void> onFundiCancel({
    required String fundiId,
    required String jobId,
    required String reason,
  }) async {
    var db = FirebaseFirestore.instance;
    var statsRef = db.collection('fundiStats').doc(fundiId);
    var fundiRef = db.collection('fundis').doc(fundiId);

    await db.runTransaction((tx) async {
      var statsSnap = await tx.get(statsRef);
      var data = statsSnap.data() ?? {};
      int count = (data['cancellationCount'] ?? 0) as int;
      List cancellations = List.from(data['cancellationHistory'] ?? []);

      int newCount = count + 1;
      cancellations.add({
        'jobId': jobId,
        'reason': reason,
        'at': DateTime.now().toIso8601String(),
      });

      DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
      int recentCancels = cancellations.where((c) {
        try {
          DateTime d = DateTime.parse(c['at']);
          return d.isAfter(cutoff);
        } catch (_) {
          return false;
        }
      }).length;

      Duration? suspension;
      String? suspensionReason;
      if (recentCancels == 1) {
        suspensionReason = 'warning';
      } else if (recentCancels == 2) {
        suspension = suspend24h;
        suspensionReason = '2 cancellations in 30 days - 24h suspension';
      } else if (recentCancels == 3) {
        suspension = suspend7d;
        suspensionReason = '3 cancellations in 30 days - 7 days suspension';
      } else if (recentCancels >= 4) {
        suspension = suspend30d;
        suspensionReason =
            '4+ cancellations in 30 days - 30 days suspension + manual review';
      }

      Map<String, dynamic> update = {
        'cancellationCount': newCount,
        'cancellationHistory': cancellations,
        'recentCancellationCount': recentCancels,
        'lastCancellationAt': FieldValue.serverTimestamp(),
        'penaltyScore': FieldValue.increment(50),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (suspension != null) {
        update['suspendedUntil'] = Timestamp.fromDate(
          DateTime.now().add(suspension),
        );
        update['suspensionReason'] = suspensionReason;
        update['isSuspended'] = true;
      } else if (recentCancels == 1) {
        update['lastWarningAt'] = FieldValue.serverTimestamp();
        update['warningReason'] = suspensionReason;
      }

      tx.set(statsRef, update, SetOptions(merge: true));
      tx.set(fundiRef, {
        'penaltyScore': FieldValue.increment(50),
        'lastCancellationAt': FieldValue.serverTimestamp(),
        'isSuspended': suspension != null ? true : FieldValue.delete(),
        'suspendedUntil': suspension != null
            ? Timestamp.fromDate(DateTime.now().add(suspension))
            : FieldValue.delete(),
      }, SetOptions(merge: true));
    });

    await db.collection('adminFlags').add({
      'type': 'fundi_cancel',
      'fundiId': fundiId,
      'jobId': jobId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<bool> canFundiBid(String fundiId) async {
    var snap = await FirebaseFirestore.instance
        .collection('fundiStats')
        .doc(fundiId)
        .get();
    if (!snap.exists) return true;
    var data = snap.data()!;
    if (data['isSuspended'] == true) {
      Timestamp? until = data['suspendedUntil'];
      if (until != null && until.toDate().isAfter(DateTime.now())) {
        return false;
      } else {
        await snap.reference.update({
          'isSuspended': false,
          'suspendedUntil': FieldValue.delete(),
        });
        return true;
      }
    }
    return true;
  }

  static Future<void> onJobCompletedOnTime(String fundiId) async {
    await FirebaseFirestore.instance.collection('fundis').doc(fundiId).set({
      'penaltyScore': FieldValue.increment(-5),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('fundiStats').doc(fundiId).set({
      'penaltyScore': FieldValue.increment(-5),
      'onTimeDeliveries': FieldValue.increment(1),
      'onTimeArrivalCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<void> onRepeatJobNoRedo({
    required String fundiId,
    required String disputeId,
    required String clientId,
    required String clientName,
    required String jobId,
    required double disputedJobAmount
  }) async {
    double refund50 = disputedJobAmount * 0.5;
    var db = FirebaseFirestore.instance;
    await db.collection('fundis').doc(fundiId).set({
      'strikes': FieldValue.increment(1),
      'pendingDeductionRemaining': FieldValue.increment(refund50),
      'pendingDeduction': FieldValue.increment(refund50),
      'pendingDeductionDisputeId': disputeId,
      'pendingDeductionClientId': clientId,
      'pendingDeductionClientName': clientName,
      'pendingDeductionOriginalJobId': jobId,
      'lastStrikeReason':
          'repeat_job - no redo after 30h (24h + 6h reminder) - dispute $disputeId',
      'strikeUpdatedAt': FieldValue.serverTimestamp(),
      'penaltyScore': FieldValue.increment(100),
    }, SetOptions(merge: true));

    await db.collection('fundiStats').doc(fundiId).set({
      'repeatJobStrikes': FieldValue.increment(1),
      'lastRepeatStrikeAt': FieldValue.serverTimestamp(),
      'pendingDeductionRemaining': FieldValue.increment(refund50),
    }, SetOptions(merge: true));

    await db.collection('disputes').doc(disputeId).update({
      'status': 'resolved_client_win_fundi_no_redo',
      'resolutionAction': 'deduct_50_next_job',
      'deductionAmount': refund50,
      'deductionOwedToClientId': clientId,
      'deductionOwedToClientName': clientName,
      'deductionRemaining': refund50,
      'deductionCreatedAt': FieldValue.serverTimestamp(),
      'fundiDeclinedRedo': true,
    });

    await db.collection('adminFlags').add({
      'type': 'repeat_job_deduction',
      'fundiId': fundiId,
      'disputeId': disputeId,
      'clientId': clientId,
      'amount': refund50,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  static Future<Map<String, dynamic>> applyPendingDeductionOnPayout({
    required String fundiId,
    required String jobId,
    required double currentJobAmount,
  }) async {
    var db = FirebaseFirestore.instance;
    var fundiSnap = await db.collection('fundis').doc(fundiId).get();
    var fundiData = fundiSnap.data() ?? {};

    double remaining = (fundiData['pendingDeductionRemaining'] ?? 0).toDouble();
    String? disputeId = fundiData['pendingDeductionDisputeId'];
    String? clientId = fundiData['pendingDeductionClientId'];

    if (remaining <= 0 || disputeId == null || clientId == null) {
      return {
        'fundiPayout': currentJobAmount,
        'deducted': 0.0,
        'remaining': 0.0,
        'message': null,
      };
    }

    double deductThisJob = min(currentJobAmount * 0.5, remaining);
    double newRemaining = remaining - deductThisJob;
    double fundiPayout = currentJobAmount - deductThisJob;

    String shortId = disputeId.length > 6
        ? disputeId.substring(0, 6)
        : disputeId;
    String message =
        'KES ${deductThisJob.toStringAsFixed(0)} deducted from your pay as a result of dispute $shortId (repeat job within 14 days - you did not redo within 24h + 6h). ${newRemaining > 0 ? "KES ${newRemaining.toStringAsFixed(0)} still owed to client ${fundiData['pendingDeductionClientName'] ?? ''} - will be deducted from next jobs until 50% refund complete." : "Deduction complete - client refunded 50%."}';
    if (deductThisJob > 0) {
      await db.collection('clients').doc(clientId).update({
        'walletBalance': FieldValue.increment(deductThisJob),
      });
      await db.collection('transactions').add({
        'userId': clientId,
        'type': 'dispute_refund_50',
        'amount': deductThisJob,
        'disputeId': disputeId,
        'fromFundiId': fundiId,
        'fromJobId': jobId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      String shortId = disputeId.length > 6
          ? disputeId.substring(0, 6)
          : disputeId;
      await db.collection('notifications').add({
        'toUserId': clientId,
        'toRole': 'client',
        'type': 'dispute_refund',
        'disputeId': disputeId,
        'title':
            'Refund received: KES ${deductThisJob.toStringAsFixed(0)} from dispute $shortId',
        'body':
            'KES ${deductThisJob.toStringAsFixed(0)} refunded to your wallet as 50% of disputed job. Fundi had repeat job within 14 days and did not redo. ${newRemaining > 0 ? "KES ${newRemaining.toStringAsFixed(0)} more will be refunded from his next jobs." : "Full 50% refund complete."}',
        'amount': deductThisJob,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await db.collection('fundis').doc(fundiId).update({
      'pendingDeductionRemaining': newRemaining,
      'pendingDeduction': newRemaining,
      if (newRemaining <= 0) 'pendingDeductionDisputeId': FieldValue.delete(),
      if (newRemaining <= 0) 'pendingDeductionClientId': FieldValue.delete(),
      if (newRemaining <= 0) 'pendingDeductionClientName': FieldValue.delete(),
    });

    await db.collection('disputes').doc(disputeId).update({
      'deductionRemaining': newRemaining,
      if (newRemaining <= 0) 'deductionFullyPaid': true,
      if (newRemaining <= 0)
        'deductionCompletedAt': FieldValue.serverTimestamp(),
    });

    await db.collection('jobs').doc(jobId).update({
      'deductionThisJob': deductThisJob,
      'deductionDisputeId': disputeId,
      'deductionRemainingAfter': newRemaining,
      'originalReleasedAmount': currentJobAmount,
      'fundiPayoutAfterDeduction': fundiPayout,
    });

    await db.collection('transactions').add({
      'userId': fundiId,
      'type': 'payout_with_deduction',
      'amount': fundiPayout,
      'deduction': deductThisJob,
      'disputeId': disputeId,
      'jobId': jobId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'fundiPayout': fundiPayout,
      'deducted': deductThisJob,
      'remaining': newRemaining,
      'message': message,
      'disputeId': disputeId,
    };
  }
}
