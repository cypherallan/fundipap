import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'timeline_utils.dart';
import '../../rating/rate_fundi_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TimelineActions {
  static Future<void> payEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'confirmed',
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowPaidAt': FieldValue.serverTimestamp(),
      'escrowHeld': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> payExtraEscrow(
    String jobId,
    int extraLabor,
    int extraToLock,
    String whoBuys,
  ) async {
    final jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    final snap = await jobRef.get();
    final job = snap.data() as Map<String, dynamic>;
    int oldLabor = toInt(
      job['lastCounterAmount'] ?? job['laborCost'] ?? job['agreedPrice'] ?? 0,
    );
    int transport = toInt(job['transportFee'] ?? 164);
    String fundiId = (job['assignedFundiId'] ?? job['fundiId'] ?? '')
        .toString();
    int fundiPct = 10;
    if (fundiId.isNotEmpty) {
      var fundiSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fundiId)
          .get();
      var fd = fundiSnap.data() ?? {};
      if (fd['badgeLevel'] == 'gold' || fd['isTrialGold'] == true)
        fundiPct = 5;
      else if (fd['badgeLevel'] == 'silver')
        fundiPct = 8;
      else if (fd['badgeLevel'] == 'bronze')
        fundiPct = 10;
      else
        fundiPct = 15;
    }
    int newLabor = oldLabor + extraLabor;
    int newClientFee = (newLabor * 0.05).round();
    int newFundiFee = (newLabor * fundiPct / 100).round();
    int newTotal = newLabor + transport + newClientFee;
    int newFundiReceives = newLabor - newFundiFee + transport;
    await jobRef.update({
      'laborCost': newLabor,
      'agreedPrice': newLabor,
      'clientAppFee': newClientFee,
      'fundiAppFee': newFundiFee,
      'totalClientPays': newTotal,
      'totalCost': newTotal,
      'escrowAmount': newTotal,
      'fundiReceives': newFundiReceives,
      'extraToLock': 0,
      'extraLaborAmount': 0,
      'extraEscrowStatus': 'paid',
      'escrowStatus': 'held',
      'clientNeedsToTopup': false,
      'status': whoBuys == 'client'
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
      'renegotiation.status': 'extra_locked',
      'renegotiation.extraLocked': true,
      'renegotiation.currentPhase': whoBuys == 'client'
          ? 'waiting_for_client_to_buy_parts'
          : 'fundi_buying_parts',
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
      'status': 'client_claims_parts_bought',
      'renegotiation.currentPhase': 'client_claims_parts_bought',
      'renegotiation.clientPartsBought': true,
      'renegotiation.clientPartsBoughtAt': FieldValue.serverTimestamp(),
      'renegotiation.status': 'client_claims_parts_bought',
      'fundiHasUnread': true,
      'customerHasUnread': false,
      'customerUnreadType': 'parts_bought',
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      job['lastCounterAmount'] ??
          bidData['lastCounterAmount'] ??
          bidData['agreedPrice'] ??
          job['laborCost'] ??
          0,
    );
    int transport = toInt(
      job['transportFee'] ?? bidData['transportFee'] ?? 100,
    );
    int fundiPctLocal = 10;
    try {
      var fundiSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(fundiId)
          .get();
      var fd = fundiSnap.data() ?? {};
      if (fd['isTrialGold'] == true)
        fundiPctLocal = 5;
      else if (fd['badgeLevel'] == 'gold')
        fundiPctLocal = 5;
      else if (fd['badgeLevel'] == 'silver')
        fundiPctLocal = 8;
      else if (fd['badgeLevel'] == 'bronze')
        fundiPctLocal = 10;
      else
        fundiPctLocal = 15;
    } catch (_) {}
    int clientFee = (labour * 0.05).round();
    int fundiFee = (labour * fundiPctLocal / 100).round();
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(jobRef.collection('bids').doc(bidId), {
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // SECURE RELEASE - calls your existing confirmCompletionSecure via HTTP (no pigeon channel)
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not logged in';
      final idToken = await user.getIdToken();

      final url = Uri.parse(
        'https://europe-west1-fundipap-global.cloudfunctions.net/confirmCompletionSecure',
      );
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'data': {'jobId': jobId},
        }),
      );

      debugPrint('Release HTTP ${resp.statusCode}: ${resp.body}');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final data = decoded['result'] ?? {};
        final int finalPayout =
            (data['fundiPayout'] ?? data['finalFundiPayout'] ?? 0).toInt();
        final int deducted =
            (data['deductionThisJob'] ?? data['deductedThisJob'] ?? 0).toInt();

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deducted > 0
                  ? 'Released KES $finalPayout to Fundi (KES $deducted deducted)'
                  : 'Released KES $finalPayout to Fundi',
            ),
          ),
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
      } else {
        final body = resp.body;
        String msg =
            body.contains('already-exists') || body.contains('Already released')
            ? 'Already released - cannot pay twice'
            : 'Failed ${resp.statusCode}: $body';
        throw msg;
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      onReleasing(false);
    }
  }
}
