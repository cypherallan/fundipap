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
    int extra,
    int newTotal,
    String currentRenegStatus,
  ) async {
    String finalStatus = currentRenegStatus.replaceAll(
      '_pending_extra_escrow',
      '',
    );
    bool clientBuys = finalStatus.contains('client_buys');
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': newTotal,
      'extraEscrowStatus': 'paid',
      'extraEscrowPaidAt': FieldValue.serverTimestamp(),
      'status': 'site_visit',
      'renegotiation.status': finalStatus,
      'renegotiation.requested': false,
      'renegotiation.currentPhase': clientBuys
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> confirmPartsBought(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.currentPhase': 'client_claims_parts_bought',
      'renegotiation.clientPartsBought': true,
      'renegotiation.clientPartsBoughtAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      int transport = toInt(j['transportFee'] ?? 0);
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
