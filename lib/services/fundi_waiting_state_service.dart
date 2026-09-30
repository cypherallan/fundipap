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
  String renegoStatus = (renego?['status'] ?? '').toString().toLowerCase();
  bool renegoPending =
      renego != null &&
      renego['requested'] == true &&
      renegoStatus == 'pending';
  bool renegoCountered =
      renegoStatus == 'countered_by_client' || renegoStatus == 'countered';

  if (renegoCountered) {
    int requestedExtra = _toInt(
      renego?['extraLabor'] ?? renego?['pendingLabor'] ?? renego?['extra'] ?? 0,
    );
    int counterExtra = _toInt(
      renego?['counterExtraLabor'] ??
          renego?['counterLabor'] ??
          renego?['counterExtra'] ??
          renego?['clientCounterExtra'] ??
          0,
    );
    if (counterExtra == 0) {
      int counterToLock = _toInt(
        renego?['counterExtraToLock'] ?? renego?['counterToLock'] ?? 0,
      );
      if (counterToLock > 0) counterExtra = (counterToLock / 1.05).round();
    }
    return FundiWaitingState(
      type: FundiWaitingType.clientCounter,
      title:
          'Client countered your extra KES $requestedExtra to KES $counterExtra',
      message:
          'Client countered extra: KES $counterExtra (you asked KES $requestedExtra). Tap to Accept / Counter / Reject',
      price: counterExtra,
    );
  }

  if (renegoPending) {
    int extra = _toInt(
      renego['extraLabor'] ??
          renego['pendingLabor'] ??
          renego['newLaborExtra'] ??
          renego['extra'] ??
          0,
    );
    if (extra == 0) {
      int extraToLock = _toInt(renego['extraToLock'] ?? 0);
      if (extraToLock > 0) extra = (extraToLock / 1.05).round();
    }
    return FundiWaitingState(
      type: FundiWaitingType.waitingNewPriceApproval,
      title: 'Waiting for client to approve extra KES $extra',
      message: 'You requested extra KES $extra',
      price: extra,
    );
  }

  if (jobStatus.contains('cancel')) return null;

  String bidStatus = (bid['status'] ?? '').toString();
  String lastBy = (bid['lastCounterBy'] ?? bid['counterBy'] ?? '').toString();

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
  if (bidStatus == 'countered' && lastBy == uid) {
    int amt = _toInt(bid['lastCounterAmount'] ?? bid['lastCounterPrice'] ?? 0);
    return FundiWaitingState(
      type: FundiWaitingType.myCounter,
      title: 'You countered • KES $amt - Waiting for client to react',
      message: 'You countered KES $amt. Waiting for client',
      price: amt,
    );
  }
  if (bidStatus == 'pending' || bidStatus == 'sent' || bidStatus == '') {
    int p = _toInt(bid['price'] ?? bid['amount'] ?? bid['bidPrice'] ?? labour);
    return FundiWaitingState(
      type: FundiWaitingType.bidSent,
      title: 'Bid sent - KES $p - Waiting for client to react',
      message: 'You sent KES $p',
      price: p,
    );
  }

  int lockedAmount = _toInt(
    job['escrowAmount'] ??
        job['lockedEscrow'] ??
        job['escrowLockedAmount'] ??
        0,
  );
  bool hasLockedAmount = lockedAmount > 0;
  bool needsTopup = hasLockedAmount && fundiSees > lockedAmount;
  int needExtra = needsTopup ? fundiSees - lockedAmount : 0;
  if (needExtra > 0) {
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
  bool isTopupWait =
      needsTopup && !travelling && !renegoPending && !renegoCountered;

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

  if (siteDone && !renegoPending && !renegoCountered) {
    return FundiWaitingState(
      type: FundiWaitingType.siteVisited,
      title: 'Waiting for you to start work - KES $fundiSees',
      message: 'You visited site. Tap START JOB',
      price: fundiSees,
    );
  }
  if (travelling && !siteDone) {
    return FundiWaitingState(
      type: FundiWaitingType.travelling,
      title: 'You are on the way',
      message: 'Travelling to client site',
      price: fundiSees,
    );
  }
  if (escrowDone &&
      !needsTopup &&
      !siteDone &&
      !travelling &&
      !renegoPending &&
      !renegoCountered) {
    return FundiWaitingState(
      type: FundiWaitingType.escrowLocked,
      title: 'Escrow locked - KES $fundiSees - Click to Start site visit now',
      message: 'Client locked KES $fundiSees. Start travelling',
      price: fundiSees,
    );
  }
  return null;
}
