import 'package:cloud_firestore/cloud_firestore.dart';

enum FundiWaitingType {
  bidSent,
  clientCounter,
  myCounter,
  waitingEscrow,
  escrowLocked,
  travelling,
  siteVisited,
  waitingNewPriceApproval,
}

class FundiWaitingState {
  final FundiWaitingType type;
  final String title;
  final String message;
  final int price;
  FundiWaitingState({
    required this.type,
    required this.title,
    required this.message,
    this.price = 0,
  });

  String get notificationCategory => title;
}

int _toInt(dynamic v, [int fb = 0]) {
  if (v == null) return fb;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  // handles "KES 1,500", "1500.0", etc
  String s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty) return fb;
  return int.tryParse(s.split('.').first) ?? fb;
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return true;
}

FundiWaitingState? getFundiWaitingState({
  required Map<String, dynamic> job,
  required Map<String, dynamic> bid,
  required List<DocumentSnapshot> counterOffers,
  required String uid,
}) {
  String bidStatus = (bid['status'] ?? '').toString();
  String lastBy = (bid['lastCounterBy'] ?? bid['counterBy'] ?? '').toString();
  String jobStatus = (job['status'] ?? '').toString().toLowerCase();
  String escrowStatus = (job['escrowStatus'] ?? '').toString().toLowerCase();
  bool escrowDone = ['held', 'paid', 'released'].contains(escrowStatus);

  bool siteDone =
      _toBool(job['siteVisitDone']) ||
      _toBool(job['siteVisited']) ||
      job['siteVisitedAt'] != null ||
      ['site_visit', 'site_visit_done', 'site_visited'].contains(jobStatus);

  bool travelling =
      !siteDone && (job['travelling'] == true || jobStatus == 'travelling');

  var renego = job['renegotiation'] as Map<String, dynamic>?;
  bool renegoPending =
      renego != null &&
      renego['requested'] == true &&
      (renego['status'] ?? 'pending') == 'pending';

  int labour = _toInt(
    job['laborCost'] ?? job['agreedPrice'] ?? job['price'] ?? bid['price'] ?? 0,
  );
  int transport = _toInt(job['transportFee'] ?? 0);
  int fundiSees = labour + transport;

  // 1. Counter
  if (bidStatus == 'countered' && lastBy != uid) {
    int p = _toInt(bid['lastCounterPrice'] ?? bid['lastCounterAmount']);
    return FundiWaitingState(
      type: FundiWaitingType.clientCounter,
      title: 'Client countered your labour charges',
      message: 'Client countered KES $p (Your bid KES ${bid['price']})',
      price: p,
    );
  }
  if (bidStatus == 'countered' && lastBy == uid) {
    int p = _toInt(
      bid['lastCounterPrice'] ?? bid['lastCounterAmount'] ?? bid['price'],
    );
    return FundiWaitingState(
      type: FundiWaitingType.myCounter,
      title: 'You countered • KES $p - Waiting for client to react',
      message: 'Waiting for client',
      price: p,
    );
  }

  // 2. Bid sent
  // 2. Bid sent
  if (bidStatus == 'pending' || bidStatus == 'sent' || bidStatus == '') {
    int p = _toInt(
      bid['price'] ??
          bid['amount'] ??
          bid['bidPrice'] ??
          bid['proposedPrice'] ??
          bid['laborCost'] ??
          job['laborCost'] ??
          job['agreedPrice'] ??
          job['price'] ??
          0,
    );
    return FundiWaitingState(
      type: FundiWaitingType.bidSent,
      title: 'Bid sent - KES $p - Waiting for client to react',
      message: 'You sent KES $p',
      price: p,
    );
  }

  // 3. Renegotiation pending
  if (renegoPending) {
    int extra = _toInt(
      renego['extraToLock'] ??
          renego['pendingLabor'] ??
          renego['extraLabor'] ??
          0,
    );
    return FundiWaitingState(
      type: FundiWaitingType.waitingNewPriceApproval,
      title: 'Waiting for client to approve extra KES $extra',
      message:
          'You requested extra labour KES $extra. Waiting for client ${job['clientName'] ?? ''} to approve',
      price: extra,
    );
  }

  // FIX: check locked amount vs needed - stops green showing before escrow
  int lockedAmount = _toInt(
    job['escrowAmount'] ??
        job['lockedEscrow'] ??
        job['escrowLockedAmount'] ??
        0,
  );
  bool hasLockedAmount = lockedAmount > 0;
  bool needsTopup = hasLockedAmount && fundiSees > lockedAmount;
  bool shouldWaitEscrow =
      (!escrowDone || needsTopup) &&
      !siteDone &&
      !travelling &&
      ['assigned', 'confirmed', 'negotiating', 'accepted'].contains(jobStatus);

  // 4. WAITING FOR ESCROW - ORANGE
  if (shouldWaitEscrow) {
    int need = needsTopup ? fundiSees - lockedAmount : fundiSees;
    return FundiWaitingState(
      type: FundiWaitingType.waitingEscrow,
      title: needsTopup
          ? 'Waiting for client to lock extra KES $need to escrow'
          : 'Waiting for client to lock KES $fundiSees to escrow',
      message: needsTopup
          ? 'Client locked KES $lockedAmount, needs extra KES $need (Total KES $fundiSees)'
          : 'Client needs to lock KES $fundiSees',
      price: need,
    );
  }

  // 5. ESCROW LOCKED - GREEN + START SITE VISIT
  if (escrowDone && !needsTopup && !siteDone && !travelling && !renegoPending) {
    return FundiWaitingState(
      type: FundiWaitingType.escrowLocked,
      title: 'Escrow locked - KES $fundiSees - Start site visit now',
      message: 'Client locked KES $fundiSees. Start travelling',
      price: fundiSees,
    );
  }

  // 6. Travelling
  if (travelling && !siteDone) {
    return FundiWaitingState(
      type: FundiWaitingType.travelling,
      title: 'You are on the way',
      message: 'Travelling to client site',
      price: fundiSees,
    );
  }

  // 7. Site visited -> START JOB / New Price
  if (siteDone && !renegoPending) {
    return FundiWaitingState(
      type: FundiWaitingType.siteVisited,
      title: 'Site visited - Done KES $fundiSees',
      message: 'You visited site. Next: START JOB or request new price',
      price: fundiSees,
    );
  }

  return null;
}
