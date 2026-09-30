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
    required this.price,
  });
}

int _toInt(dynamic v, [int fb = 0]) {
  if (v == null) return fb;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  String s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty) return fb;
  return int.tryParse(s.split('.').first) ?? fb;
}

bool _toBool(dynamic v, [bool fb = false]) {
  if (v == null) return fb;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  if (v is Timestamp) return true;
  return fb;
}

FundiWaitingState? getFundiWaitingState({
  required Map<String, dynamic> job,
  required Map<String, dynamic> bid,
  required List<DocumentSnapshot> counterOffers,
  required String uid,
}) {
  String jobStatus = (job['status'] ?? '').toString().toLowerCase();
  String escrowStatus = (job['escrowStatus'] ?? 'pending')
      .toString()
      .toLowerCase();
  bool escrowDone = ['held', 'paid', 'released'].contains(escrowStatus);

  int labour = _toInt(
    job['laborCost'] ??
        job['agreedPrice'] ??
        job['price'] ??
        bid['price'] ??
        bid['amount'] ??
        0,
  );
  int transport = _toInt(job['transportFee'] ?? 0);
  int fundiSees = labour + transport;

  bool siteDone =
      _toBool(job['siteVisitDone']) ||
      _toBool(job['siteVisited']) ||
      job['siteVisitedAt'] != null ||
      ['site_visit', 'site_visit_done', 'site_visited'].contains(jobStatus);

  bool travelling =
      !siteDone &&
      (_toBool(job['travelling']) ||
          jobStatus == 'travelling' ||
          jobStatus == 'on_the_way');

  var renego = job['renegotiation'] as Map<String, dynamic>?;
  bool renegoPending =
      renego != null &&
      renego['requested'] == true &&
      (renego['status'] ?? 'pending') == 'pending';
  bool isCancelled = jobStatus.contains('cancel');

  if (isCancelled) return null;

  String bidStatus = (bid['status'] ?? '').toString();
  String lastBy = (bid['lastCounterBy'] ?? bid['counterBy'] ?? '').toString();

  // 1. Client counter pending - fundi must react
  if ((bidStatus == 'countered' && lastBy != uid) ||
      bidStatus == 'client_counter') {
    int amt = _toInt(
      bid['lastCounterAmount'] ??
          bid['lastCounterPrice'] ??
          bid['clientCounterAmount'] ??
          0,
    );
    return FundiWaitingState(
      type: FundiWaitingType.clientCounter,
      title: 'Client countered your labour charges',
      message: 'Client countered: KES $amt',
      price: amt,
    );
  }

  // 2. My counter pending - waiting client
  if (bidStatus == 'countered' && lastBy == uid) {
    int amt = _toInt(bid['lastCounterAmount'] ?? bid['lastCounterPrice'] ?? 0);
    return FundiWaitingState(
      type: FundiWaitingType.myCounter,
      title: 'You countered • KES $amt - Waiting for client to react',
      message:
          'You countered KES $amt. Waiting for client to accept, counter or reject...',
      price: amt,
    );
  }

  // 3. Renegotiation new price pending - FIX 0 bug
  if (renegoPending) {
    // You save as extraToLock / pendingLabor / extraLabor / newLabor after site visit
    int extra = _toInt(
      renego['extraToLock'] ??
          renego['pendingLabor'] ??
          renego['extraLabor'] ??
          renego['newLabor'] ??
          0,
    );
    int total = _toInt(
      renego['newPrice'] ??
          renego['newTotal'] ??
          renego['totalPrice'] ??
          renego['amount'] ??
          renego['newAmount'] ??
          0,
    );

    // display total if you have it, otherwise extra, otherwise fallback to fundiSees
    int displayPrice = total > 0 ? total : (extra > 0 ? extra : fundiSees);
    // if extra is the diff, show total = fundiSees + extra for clarity
    int priceForState = total > 0
        ? total
        : (extra > 0 ? fundiSees + extra : fundiSees);

    return FundiWaitingState(
      type: FundiWaitingType.waitingNewPriceApproval,
      title: extra > 0 && total == 0
          ? 'Waiting for client to approve extra KES $extra (Total KES $priceForState)'
          : 'Waiting for client to approve new price KES $displayPrice',
      message: extra > 0 && total == 0
          ? 'You requested extra KES $extra on top of KES $fundiSees'
          : 'You requested new price KES $displayPrice',
      price: priceForState,
    );
  }

  // 4. Bid sent
  if (bidStatus == 'pending' || bidStatus == 'sent' || bidStatus == '') {
    int p = _toInt(
      bid['price'] ??
          bid['amount'] ??
          bid['bidPrice'] ??
          bid['proposedPrice'] ??
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

  // 5. WAITING FOR ESCROW - ORANGE
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

  // 6. Site visited -> WAITING FOR YOU TO START WORK - MUST BE BEFORE escrowLocked
  if (siteDone && !renegoPending) {
    return FundiWaitingState(
      type: FundiWaitingType.siteVisited,
      title: 'Waiting for you to start work - KES $fundiSees',
      message: 'You visited site. Tap START JOB to begin work',
      price: fundiSees,
    );
  }

  // 7. Travelling
  if (travelling && !siteDone) {
    return FundiWaitingState(
      type: FundiWaitingType.travelling,
      title: 'You are on the way',
      message: 'Travelling to client site',
      price: fundiSees,
    );
  }

  // 8. ESCROW LOCKED - GREEN + START SITE VISIT
  if (escrowDone && !needsTopup && !siteDone && !travelling && !renegoPending) {
    return FundiWaitingState(
      type: FundiWaitingType.escrowLocked,
      title: 'Escrow locked - KES $fundiSees - Click to Start site visit now',
      message: 'Client locked KES $fundiSees. Start travelling',
      price: fundiSees,
    );
  }

  return null;
}
