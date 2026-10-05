import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/timeline_utils.dart';
import '../widgets/green_done_card.dart';
import '../../../../../services/fundi_waiting_state_service.dart';

List<Widget> buildDoneHistory({
  required Map<String, dynamic> job,
  required List<DocumentSnapshot> coDocs,
  required String uid,
  required int myBidPrice,
  required List<Map<String, dynamic>> priceHistory,
  required FundiWaitingState? waitingState,
  required String clientName,
  required String jobTitle,
  required int labour,
  required int transport,
  required int fundiSees,
  required bool escrowDone,
  required bool siteDone,
  required String status,
}) {
  List<Widget> doneHistory = [];

  // Counter offers history - ORIGINAL LOGIC
  for (int i = 0; i < coDocs.length; i++) {
    var co = coDocs[i].data() as Map<String, dynamic>;
    int price = toInt(co['price'] ?? 0);
    String by = (co['by'] ?? '').toString();
    bool isLast = i == coDocs.length - 1;
    if (isLast &&
        ((by != uid && waitingState?.type == FundiWaitingType.clientCounter) ||
            (by == uid && waitingState?.type == FundiWaitingType.myCounter)))
      continue;
    if (by != uid) {
      doneHistory.add(
        greenDoneCard(
          title: 'Client countered - KES $price - Done',
          message: 'Client $clientName countered KES $price • You reacted',
          icon: Icons.compare_arrows,
        ),
      );
    } else {
      doneHistory.add(
        greenDoneCard(
          title: 'You countered - KES $price - Done',
          message: 'You countered KES $price • Client reacted',
          icon: Icons.compare_arrows,
        ),
      );
    }
  }

  if (waitingState == null || waitingState.type != FundiWaitingType.bidSent) {
    doneHistory.add(
      greenDoneCard(
        title: 'Bid sent - KES $myBidPrice - Done',
        message: 'You sent bid KES $myBidPrice for $jobTitle • $clientName',
      ),
    );
  }

  for (var ph in priceHistory) {
    if ((ph['type'] ?? '') == 'accepted_client_counter') {
      doneHistory.add(
        greenDoneCard(
          title: 'You accepted client counter KES ${toInt(ph['price'])} - Done',
          message: 'You accepted KES ${toInt(ph['price'])} • Job assigned',
        ),
      );
    }
  }

  String curStatus = (job['status'] ?? '').toString().toLowerCase();
  bool hasCounterAccepted =
      priceHistory.any((e) => (e['type'] ?? '') == 'accepted_client_counter') ||
      (job['counterAcceptedBy'] as List?)?.isNotEmpty == true;
  bool beyondCounterAccepted =
      [
        'assigned',
        'confirmed',
        'travelling',
        'on_the_way',
        'site_visit',
        'site_visit_done',
        'site_visited',
        'in_progress',
        'pending_completion',
        'job_completed',
        'completed',
      ].contains(curStatus) ||
      (job['escrowStatus'] ?? '').toString().toLowerCase() == 'held' ||
      (job['escrowStatus'] ?? '').toString().toLowerCase() == 'paid';
  if (hasCounterAccepted && beyondCounterAccepted) {
    doneHistory.add(
      greenDoneCard(
        title: 'Counter offer accepted - KES $fundiSees - Done',
        message:
            'Client confirmed your counter KES $fundiSees - waiting for escrow lock',
        icon: Icons.check_circle,
      ),
    );
  }

  if (escrowDone && !siteDone) {
    if (waitingState?.type != FundiWaitingType.waitingEscrow) {
      doneHistory.add(
        greenDoneCard(
          title: 'Escrow locked - Done KES $fundiSees',
          message:
              'Labour KES $labour + Transport KES $transport = KES $fundiSees locked',
        ),
      );
    }
  }

  bool isSiteDone =
      (job['siteVisitDone'] == true) ||
      (job['siteVisited'] == true) ||
      job['siteVisitedAt'] != null ||
      [
        'site_visit',
        'site_visit_done',
        'site_visited',
        'in_progress',
        'pending_completion',
        'job_completed',
      ].contains(curStatus);
  if (isSiteDone) {
    if (waitingState?.type != FundiWaitingType.travelling) {
      doneHistory.add(
        greenDoneCard(
          title: 'You arrived on site - Done',
          message: 'You marked site as visited - Done',
          icon: Icons.location_on,
        ),
      );
    }
  }
  if (siteDone && waitingState?.type != FundiWaitingType.siteVisited) {
    doneHistory.add(
      greenDoneCard(
        title: 'Site visited - Done',
        message: 'You visited site • Done',
      ),
    );
  }

  final renego = job['renegotiation'] as Map<String, dynamic>?;
  if (renego != null) {
    int accepted = toInt(
      renego['acceptedCounterExtraLabor'] ?? renego['counterExtraLabor'],
    );
    if (accepted > 0) {
      int currentTotal = toInt(job['agreedPrice'] ?? job['laborCost'] ?? 6000);
      int oldLab = currentTotal - accepted;
      if (oldLab < 0) oldLab = 5000;
      doneHistory.add(
        greenDoneCard(
          title: 'You accepted client counter extra KES $accepted - Done',
          message:
              'Old KES $oldLab + Extra KES $accepted = New labour KES $currentTotal - Done',
          icon: Icons.check_circle,
        ),
      );
    }
    bool locked =
        toBool(renego['extraLocked']) ||
        toInt(job['extraTopupAmount']) == 0 &&
            (job['status'] == 'waiting_for_client_to_buy_parts' ||
                renego['status'] == 'accepted_client_buys_parts');
    if (locked && toInt(renego['acceptedCounterExtraLabor'] ?? 0) > 0) {
      int extra = toInt(renego['acceptedCounterExtraLabor']);
      doneHistory.add(
        greenDoneCard(
          title: 'Client locked extra KES $extra - Done',
          message:
              'Client locked extra KES $extra • New labour KES ${toInt(job['agreedPrice'])} • Done',
          icon: Icons.lock,
        ),
      );
    }
    bool materialsConfirmed =
        toBool(renego['materialsConfirmed']) ||
        toBool(renego['partsConfirmed']) ||
        toBool(job['materialsConfirmed']) ||
        (renego['currentPhase'] ?? '').toString().toLowerCase().contains(
          'materials_confirmed',
        ) ||
        (renego['currentPhase'] ?? '').toString().toLowerCase().contains(
          'parts_confirmed',
        ) ||
        (job['status'] ?? '').toString().toLowerCase().contains(
          'materials_confirmed',
        );
    bool pastBoughtPhase =
        [
          'in_progress',
          'site_visit',
          'site_visit_done',
          'site_visited',
          'pending_completion',
        ].contains(status) &&
        toInt(renego['acceptedCounterExtraLabor'] ?? 0) > 0;
    if (materialsConfirmed || pastBoughtPhase) {
      doneHistory.add(
        greenDoneCard(
          title: 'You confirmed materials bought - Done',
          message:
              'You confirmed client bought materials • Ready to start work • Done',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }
  }

  return doneHistory;
}
