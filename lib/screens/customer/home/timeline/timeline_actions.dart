import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'timeline_utils.dart';
import '../../rating/rate_fundi_screen.dart';

class TimelineActions {
  static Future<void> payEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowPaidAt': FieldValue.serverTimestamp(),
      'escrowHeld': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> payExtraEscrow(
    String jobId,
    int extra, // extraToLock = 1050 (1000+50) not 6400
    int newTotal, // newTotal = 6400 (5350+1050)
    String currentRenegStatus,
  ) async {
    String finalStatus = currentRenegStatus.replaceAll(
      '_pending_extra_escrow',
      '',
    );
    // FIX: get real whoBuys, don't guess from status
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final snap = await jobRef.get();
    String whoBuys = 'client';
    if (snap.exists) {
      var data = snap.data() as Map<String, dynamic>;
      var reneg = data['renegotiation'] as Map<String, dynamic>?;
      whoBuys =
          (reneg?['whoBuysParts'] ??
                  (finalStatus.contains('client_buys') ? 'client' : 'client'))
              .toString();
    }
    bool clientBuys = whoBuys == 'client';

    await jobRef.update({
      'escrowStatus': 'held',
      'escrowAmount': newTotal, // 6400
      'extraEscrowStatus': 'paid',
      'extraEscrowPaidAt': FieldValue.serverTimestamp(),
      'extraToLock': extra, // 1050
      'renegotiation.extraToLock': extra,
      // FIX: was 'site_visit' -> caused straight to START JOB
      'status': clientBuys
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'renegotiation.status': finalStatus, // accepted_client_buys_parts
      'renegotiation.requested': false,
      'renegotiation.currentPhase': clientBuys
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'renegotiation.whoBuysParts': whoBuys,
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> confirmPartsBought(String jobId) async {
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final snap = await jobRef.get();
    String fundiId = '';
    String clientName = 'Client';
    if (snap.exists) {
      var data = snap.data() as Map<String, dynamic>;
      fundiId = (data['assignedFundiId'] ?? data['fundiId'] ?? '').toString();
      clientName = (data['customerName'] ?? data['clientName'] ?? 'Client')
          .toString();
    }

    await jobRef.update({
      'status':
          'client_claims_parts_bought', // FIX: was missing, fundi timeline needs this
      'renegotiation.currentPhase': 'client_claims_parts_bought',
      'renegotiation.clientPartsBought': true,
      'renegotiation.clientPartsBoughtAt': FieldValue.serverTimestamp(),
      'renegotiation.status': 'client_claims_parts_bought',
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'customerUnreadType': 'parts_bought',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // FIX: send notification to fundi
    if (fundiId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': fundiId,
          'toRole': 'fundi',
          'type': 'parts_bought',
          'jobId': jobId,
          'title': 'Client bought parts',
          'body':
              '$clientName marked materials as bought - confirm to start work',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance
            .collection('fundis')
            .doc(fundiId)
            .collection('notifications')
            .add({
              'jobId': jobId,
              'type': 'parts_bought',
              'title': 'Client bought parts',
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    }
  }

  static Future<void> proceedWithFundi(
    String jobId,
    String fundiId,
    int expectedTotal,
  ) async {
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final jobSnap = await jobRef.get();
    if (!jobSnap.exists) throw 'Job not found';
    final job = jobSnap.data() as Map<String, dynamic>;

    final q = await jobRef
        .collection('bids')
        .where('fundiId', isEqualTo: fundiId)
        .where(
          'status',
          whereIn: [
            'counter_accepted_by_fundi',
            'countered',
            'counter_accepted',
          ],
        )
        .limit(1)
        .get();
    final bidSnap = q.docs.isNotEmpty
        ? q.docs.first
        : (await jobRef
                  .collection('bids')
                  .where('status', isEqualTo: 'counter_accepted_by_fundi')
                  .limit(1)
                  .get())
              .docs
              .first;
    final bidId = bidSnap.id;
    final bidData = bidSnap.data();

    int labour = toInt(
      bidData['agreedPrice'] ??
          bidData['price'] ??
          job['laborCost'] ??
          job['agreedPrice'] ??
          0,
    );
    int transport = toInt(
      job['transportFee'] ?? bidData['transportFee'] ?? 100,
    );
    int clientFee = (labour * 0.05).round();
    int fundiFee = (labour * 0.05).round();
    int totalClient = labour + transport + clientFee;
    int fundiRec = labour - fundiFee + transport;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(jobRef, {
      'status': 'assigned',
      'assignedFundiId': fundiId,
      'assignedFundi': fundiId,
      'agreedPrice': labour,
      'laborCost': labour,
      'acceptedBidAmount': labour,
      'transportFee': transport,
      'clientAppFee': clientFee,
      'fundiAppFee': fundiFee,
      'totalClientPays': totalClient,
      'fundiReceives': fundiRec,
      'fundiPayoutAmount': fundiRec,
      'proceededAt': FieldValue.serverTimestamp(),
      'proceededWithFundiId': fundiId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(jobRef.collection('bids').doc(bidId), {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final others = await jobRef
        .collection('bids')
        .where(
          'status',
          whereIn: [
            'counter_accepted_by_fundi',
            'countered',
            'pending',
            'bidding',
          ],
        )
        .get();
    for (var d in others.docs) {
      if (d.id != bidId) {
        batch.update(d.reference, {
          'status': 'rejected',
          'rejectedReason': 'client_proceeded_with_other_fundi',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  static Future<void> confirmCompletion({
    required String jobId,
    required String fundiId,
    required String fundiName,
    required String trade,
    required BuildContext context,
    required Function(bool) onReleasing,
  }) async {
    onReleasing(true);
    try {
      var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
      var snap = await jobRef.get();
      if (!snap.exists) throw 'Job not found';
      var j = snap.data() as Map<String, dynamic>;
      var reneg = j['renegotiation'] as Map<String, dynamic>?;

      int labour = toInt(j['laborCost'] ?? j['agreedPrice'] ?? 0);
      int transport = toInt(j['transportFee'] ?? 100);
      int clientAppFee = toInt(j['clientAppFee'] ?? (labour * 0.05).round());
      int fundiAppFee = toInt(j['fundiAppFee'] ?? (labour * 0.05).round());
      int totalClient = toInt(
        j['totalClientPays'] ??
            j['totalCost'] ??
            labour + transport + clientAppFee,
      );
      int fundiReceives = toInt(
        j['fundiReceives'] ?? labour - fundiAppFee + transport,
      );

      if (reneg != null && reneg['newLaborTotal'] != null) {
        int newLabour = toInt(reneg['newLaborTotal']);
        int newTotalClient = toInt(
          reneg['newTotalClientPays'] ??
              newLabour + transport + (newLabour * 0.05).round(),
        );
        int newFundiReceives = toInt(
          reneg['newFundiReceives'] ??
              newLabour - (newLabour * 0.05).round() + transport,
        );
        totalClient = newTotalClient > 0 ? newTotalClient : totalClient;
        fundiReceives = newFundiReceives > 0 ? newFundiReceives : fundiReceives;
      }

      int alreadyLocked = toInt(j['escrowAmount'] ?? totalClient);

      await jobRef.update({
        'status': 'completed',
        'escrowStatus': 'released',
        'extraEscrowStatus': 'released',
        'clientConfirmedComplete': true,
        'completedAt': FieldValue.serverTimestamp(),
        'totalReleasedAmount': totalClient,
        'fundiPayoutAmount': fundiReceives,
        'fundiReceives': fundiReceives,
        'totalClientPaid': totalClient,
        'initialEscrowReleased': alreadyLocked,
        'fundiHasUnread': true,
        'customerHasUnread': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await FirebaseFirestore.instance
            .collection('escrowTransactions')
            .doc(jobId)
            .set({
              'jobId': jobId,
              'fundiId': fundiId,
              'status': 'released',
              'amount': totalClient,
              'fundiPayout': fundiReceives,
              'initialAmount': alreadyLocked,
              'releasedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('escrowTransactions set error $e');
      }

      if (!context.mounted) return;
      int displayRelease = labour + transport;
      if (reneg != null && reneg['newLaborTotal'] != null) {
        displayRelease = toInt(reneg['newLaborTotal']) + transport;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Released KES $displayRelease to Fundi')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RateFundiScreen(
            jobId: jobId,
            fundiId: fundiId,
            fundiName: fundiName,
            trade: trade,
          ),
        ),
      );
    } catch (e) {
      debugPrint('CONFIRM COMPLETION ERROR $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to release: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      onReleasing(false);
    }
  }
}
