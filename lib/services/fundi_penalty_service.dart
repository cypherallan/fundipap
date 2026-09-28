import 'package:cloud_firestore/cloud_firestore.dart';

class FundiPenaltyService {
  // Suspension durations
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

      // Keep only last 90 days for rate check
      DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
      int recentCancels = cancellations.where((c) {
        try {
          DateTime d = DateTime.parse(c['at']);
          return d.isAfter(cutoff);
        } catch (_) {
          return false;
        }
      }).length;

      // Determine suspension
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
        'penaltyScore': FieldValue.increment(
          50,
        ), // pushes fundi to bottom of search
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

    // Flag for admin
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
        return false; // still suspended
      } else {
        // auto unsuspend
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
    // Reduce penaltyScore by 5 for good behavior
    await FirebaseFirestore.instance.collection('fundis').doc(fundiId).set({
      'penaltyScore': FieldValue.increment(-5),
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('fundiStats').doc(fundiId).set({
      'penaltyScore': FieldValue.increment(-5),
      'onTimeDeliveries': FieldValue.increment(1),
      'onTimeArrivalCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}
