import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../fundi_visit_customer_tab.dart';
import '../../rating/rate_client_screen.dart';
import '../../../../app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fundi_timeline_utils.dart';

class FundiTimelineActions {
  static void goBackToMyJobs(BuildContext context, {int tab = 1}) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeNavigator(
          role: 'fundi',
          email: email,
          initialIndex: 2,
          initialJobStatusTab: tab,
        ),
      ),
      (r) => false,
    );
  }

  static Future<void> startSiteVisit(
    BuildContext context,
    String jobId,
    String jobTitle,
  ) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'siteVisitStartedAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VisitCustomerScreen(jobId: jobId, job: {'title': jobTitle}),
      ),
    );
  }

  static Future<void> confirmPartsAvailable(String jobId) async {
    final jobSnap = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
    String clientId = '';
    if (jobSnap.exists) {
      var d = jobSnap.data() as Map<String, dynamic>;
      clientId = (d['customerId'] ?? d['clientId'] ?? '').toString();
    }
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'parts_confirmed_by_fundi',
      'renegotiation.currentPhase': 'parts_confirmed_by_fundi',
      'renegotiation.partsConfirmedByFundi': true,
      'renegotiation.partsConfirmedAt': FieldValue.serverTimestamp(),
      'renegotiation.status': 'parts_confirmed_by_fundi',
      'customerHasUnread': true,
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (clientId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('notifications').add({
          'toUserId': clientId,
          'toRole': 'client',
          'type': 'parts_confirmed',
          'jobId': jobId,
          'title': 'Fundi confirmed parts',
          'body': 'Fundi confirmed materials available - waiting to start job',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  static Future<void> startJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'renegotiation.currentPhase': 'fundi_working',
      'workStartedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> completeJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'job_completed',
      'renegotiation.currentPhase': 'completed_by_fundi',
      'completedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> confirmPaymentReceived(
    BuildContext context,
    String jobId,
    String clientId,
    String clientName,
    String jobTitle,
  ) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'fundiConfirmedPayment': true,
      'fundiPaymentConfirmedAt': FieldValue.serverTimestamp(),
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RateClientScreen(
          jobId: jobId,
          clientId: clientId,
          clientName: clientName,
          trade: jobTitle,
        ),
      ),
    );
  }

  static Future<void> acceptCounter(
    String jobId,
    Map<String, dynamic>? reneg,
    int labour,
    int transport,
  ) async {
    int counterExtraClient = toInt(reneg?['counterExtraLabor'] ?? 0);
    int counterToLockClient = toInt(
      reneg?['counterExtraToLock'] ??
          counterExtraClient + (counterExtraClient * 0.05).round(),
    );
    int oldLab = toInt(reneg?['oldLabor'] ?? labour);
    int oldTrans = toInt(reneg?['oldTransportFee'] ?? transport);
    int alreadyLocked = oldLab + oldTrans + (oldLab * 0.05).round();
    int newLabTotal = oldLab + counterExtraClient;
    int newTotalClient = alreadyLocked + counterToLockClient;
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.acceptedCounterExtraLabor': counterExtraClient,
      'renegotiation.acceptedCounterExtraToLock': counterToLockClient,
      'renegotiation.acceptedCounterExtraAppFee': (counterExtraClient * 0.05)
          .round(),
      'renegotiation.newLaborTotal': newLabTotal,
      'renegotiation.newTotalClientPays': newTotalClient,
      'renegotiation.extraToLock': counterToLockClient,
      'renegotiation.extraLabor': counterExtraClient,
      'renegotiation.newClientAppFee': (newLabTotal * 0.05).round(),
      'renegotiation.newFundiAppFee': (newLabTotal * 0.05).round(),
      'renegotiation.status': 'accepted_counter_pending_extra_escrow',
      'renegotiation.currentPhase': 'waiting_for_extra_escrow',
      'renegotiation.acceptedCounterAt': FieldValue.serverTimestamp(),
      'status': 'awaiting_extra_escrow',
      'agreedPrice': newLabTotal,
      'laborCost': newLabTotal,
      'totalClientPays': newTotalClient,
      'extraLaborAmount': counterExtraClient,
      'extraToLock': counterToLockClient,
      'fundiHasUnread': false,
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
