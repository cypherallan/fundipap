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

  // First agreed price already includes transport and is already locked
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

  if (jobStatus.contains('cancel')) return null;

  String bidStatus = (bid['status'] ?? '').toString();
  String lastBy = (bid['lastCounterBy'] ?? bid['counterBy'] ?? '').toString();

  // 1. Client counter
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

  // 2. My counter
  if (bidStatus == 'countered' && lastBy == uid) {
    int amt = _toInt(bid['lastCounterAmount'] ?? bid['lastCounterPrice'] ?? 0);
    return FundiWaitingState(
      type: FundiWaitingType.myCounter,
      title: 'You countered • KES $amt - Waiting for client to react',
      message: 'You countered KES $amt. Waiting for client',
      price: amt,
    );
  }

  // 3. NEW PRICE - transport already locked, show ONLY extra labour fundi asked for, no 5% fee
  if (renegoPending) {
    int extra = _toInt(
      renego['extraLabor'] ??
          renego['pendingLabor'] ??
          renego['newLaborExtra'] ??
          renego['requestedExtra'] ??
          renego['extra'] ??
          renego['counterExtraLabor'] ??
          0,
    );

    // fallback: if only extraToLock exists (2100), strip 5% fee -> 2000
    if (extra == 0) {
      int extraToLock = _toInt(renego['extraToLock'] ?? 0);
      if (extraToLock > 0) {
        extra = (extraToLock / 1.05).round(); // 2100 -> 2000
      } else {
        int newLabour = _toInt(
          renego['newPrice'] ?? renego['newTotal'] ?? renego['newLabor'] ?? 0,
        );
        if (newLabour > labour) extra = newLabour - labour;
      }
    }

    return FundiWaitingState(
      type: FundiWaitingType.waitingNewPriceApproval,
      title: 'Waiting for client to approve extra KES $extra',
      message: 'You requested extra KES $extra',
      price: extra,
    );
  }

  // 4. Bid sent
  if (bidStatus == 'pending' || bidStatus == 'sent' || bidStatus == '') {
    int p = _toInt(bid['price'] ?? bid['amount'] ?? bid['bidPrice'] ?? labour);
    return FundiWaitingState(
      type: FundiWaitingType.bidSent,
      title: 'Bid sent - KES $p - Waiting for client to react',
      message: 'You sent KES $p',
      price: p,
    );
  }

  // FIX: locked amount already includes transport from first price
  int lockedAmount = _toInt(
    job['escrowAmount'] ??
        job['lockedEscrow'] ??
        job['escrowLockedAmount'] ??
        0,
  );
  bool hasLockedAmount = lockedAmount > 0;
  bool needsTopup = hasLockedAmount && fundiSees > lockedAmount;
  int needExtra = needsTopup ? fundiSees - lockedAmount : 0;

  // if needExtra is 2100 due to 5% leakage, fundi sees 2000
  int needExtraForFundi = needExtra > 0 ? (needExtra / 1.05).round() : 0;
  if (needExtra % 100 != 0 && needExtraForFundi * 1.05 == needExtra) {
    needExtra = needExtraForFundi;
  } else if (hasLockedAmount) {
    // prefer pure extraLabor if available
    int pureExtra = _toInt(
      renego?['extraLabor'] ?? renego?['pendingLabor'] ?? 0,
    );
    if (pureExtra > 0) needExtra = pureExtra;
  }

  bool isInitialEscrowWait =
      !escrowDone &&
      !siteDone &&
      !travelling &&
      ['assigned', 'confirmed', 'negotiating', 'accepted'].contains(jobStatus);
  bool isTopupWait = needsTopup && !travelling && !renegoPending;

  // 5. WAITING FOR ESCROW - transport already included, extra is labour only
  if (isInitialEscrowWait || isTopupWait) {
    return FundiWaitingState(
      type: FundiWaitingType.waitingEscrow,
      title: isTopupWait
          ? 'Waiting for client to lock extra KES $needExtra to escrow'
          : 'Waiting for client to lock KES $fundiSees to escrow',
      message: isTopupWait
          ? 'Waiting for client to lock extra KES $needExtra'
          : 'Waiting for client to lock KES $fundiSees',
      price: isTopupWait ? needExtra : fundiSees,
    );
  }

  // 6. SITE VISITED - transport already included in KES
  if (siteDone && !renegoPending) {
    return FundiWaitingState(
      type: FundiWaitingType.siteVisited,
      title: 'Waiting for you to start work - KES $fundiSees',
      message: 'You visited site. Tap START JOB',
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

  // 8. Escrow locked - first price incl transport already locked
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
