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
  working,
  jobCompleted,
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
  if (v is double) return v != 0;
  if (v is String) {
    String l = v.toLowerCase();
    if (l == 'true' || l == '1' || l == 'yes') return true;
    if (l == 'false' || l == '0' || l == 'no') return false;
  }
  if (v is Timestamp) return true;
  return fb;
}

bool _hasParts(Map<String, dynamic>? renego) {
  if (renego == null) return false;
  var list = renego['partsNeeded'] as List?;
  if (list != null && list.isNotEmpty) return true;
  int est = _toInt(renego['partsEstimateTotal']);
  int total = _toInt(renego['totalPartsEstimate']);
  String till = (renego['tillNumber'] ?? '').toString().trim();
  return est > 0 || total > 0 || till.isNotEmpty;
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

  // FIX: must be here at top - before isCompletedLike
  if (jobStatus.contains('cancel') ||
      _toBool(job['cancelled']) ||
      _toBool(job['autoCancelled']) ||
      jobStatus == 'auto_cancelled' ||
      jobStatus == 'cancelled_after_arrival' ||
      jobStatus == 'auto_cancelled_no_arrival')
    return null;

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

  Map<String, dynamic>? renegoEarly;
  var rawRenegoEarly = job['renegotiation'];
  if (rawRenegoEarly is Map) {
    renegoEarly = Map<String, dynamic>.from(rawRenegoEarly);
  }
  String earlyPhase = (renegoEarly?['currentPhase'] ?? '')
      .toString()
      .toLowerCase();

  bool isCompletedLike =
      jobStatus.contains('complet') ||
      jobStatus.contains('closed') ||
      jobStatus.contains('done') ||
      jobStatus.contains('rated') ||
      earlyPhase.contains('complet') ||
      earlyPhase.contains('released') ||
      escrowStatus == 'released' ||
      _toBool(job['fundiConfirmedPayment']) ||
      _toBool(job['clientConfirmedCompletion']) ||
      _toBool(job['escrowReleased']) ||
      _toBool(job['isCompleted']);

  if (isCompletedLike) {
    if (escrowStatus == 'released' || _toBool(job['escrowReleased'])) {
      int total = _toInt(
        job['totalClientPays'] ?? job['escrowAmount'] ?? fundiSees,
      );
      return FundiWaitingState(
        type: FundiWaitingType.jobCompleted,
        title: 'Client released KES $total - Tap to view receipt of payment',
        message: 'Client released KES $total',
        price: total,
      );
    }
    return FundiWaitingState(
      type: FundiWaitingType.jobCompleted,
      title: 'Job Completed - Waiting for client to confirm',
      message:
          'You marked job as completed. Waiting for client to confirm and release payment',
      price: fundiSees,
    );
  }

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

  Map<String, dynamic>? renego;
  var rawRenego = job['renegotiation'];
  if (rawRenego is Map) renego = Map<String, dynamic>.from(rawRenego);
  String renegoPhase = (renego?['currentPhase'] ?? '').toString().toLowerCase();
  String renegoStatus = (renego?['status'] ?? '').toString().toLowerCase();
  bool extraLocked = _toBool(renego?['extraLocked']);

  String lowStatus = jobStatus.toLowerCase();
  String lowPhase = renegoPhase.toLowerCase();

  bool hasParts = _hasParts(renego);
  int extraLaborReq = _toInt(renego?['extraLabor'] ?? 0);
  int extraToLockReq = _toInt(renego?['extraToLock'] ?? 0);
  int partsTotal = _toInt(
    renego?['partsEstimateTotal'] ?? renego?['totalPartsEstimate'] ?? 0,
  );
  bool isMaterialsOnly = hasParts && extraLaborReq == 0 && extraToLockReq == 0;

  // FIX: If no parts, go to siteVisited not working
  if ((lowStatus.contains('waiting_for_client_to_buy') ||
          lowPhase.contains('waiting_for_client_to_buy')) &&
      !hasParts) {
    return FundiWaitingState(
      type: FundiWaitingType.siteVisited,
      title: 'Waiting for you to start work - KES $fundiSees',
      message:
          'Extra labour KES ${_toInt(renego?['acceptedCounterExtraLabor'] ?? 0)} locked, no materials needed. Tap START JOB',
      price: fundiSees,
    );
  }
  if ((lowStatus.contains('bought') ||
          lowPhase.contains('bought') ||
          lowStatus.contains('fundi_buying') ||
          lowPhase.contains('fundi_buying')) &&
      !hasParts) {
    return FundiWaitingState(
      type: FundiWaitingType.siteVisited,
      title: 'Waiting for you to start work - KES $fundiSees',
      message: 'No materials flow, ready to start work',
      price: fundiSees,
    );
  }

  bool hasAcceptedExtra =
      _toInt(
        renego?['acceptedCounterExtraLabor'] ??
            renego?['counterExtraLabor'] ??
            renego?['acceptedExtra'] ??
            0,
      ) >
      0;
  bool isInMaterialFlow =
      hasParts &&
      (hasAcceptedExtra ||
          extraLocked ||
          renegoStatus.contains('accepted_client_buys') ||
          lowPhase.contains('buy_parts') ||
          lowPhase.contains('bought') ||
          lowStatus.contains('buy_parts') ||
          lowStatus.contains('bought') ||
          lowStatus.contains('fundi_buying') ||
          lowPhase.contains('fundi_buying') ||
          isMaterialsOnly);

  bool isWaitingBuy =
      lowStatus.contains('waiting_for_client_to_buy') ||
      lowPhase.contains('waiting_for_client_to_buy');
  bool isClientBought =
      lowStatus.contains('bought') ||
      lowPhase.contains('bought') ||
      lowStatus.contains('fundi_buying') ||
      lowPhase.contains('fundi_buying') ||
      lowStatus.contains('parts_bought') ||
      lowStatus.contains('awaiting_fundi');

  if (isInMaterialFlow) {
    if (isClientBought) {
      int totalLab = _toInt(job['agreedPrice'] ?? labour);
      return FundiWaitingState(
        type: FundiWaitingType.siteVisited,
        title: 'Client bought materials - Confirm receipt',
        message:
            'Client uploaded receipt • Tap to confirm materials and start job • KES $totalLab',
        price: totalLab,
      );
    }
    if (isWaitingBuy) {
      int totalLab = _toInt(job['agreedPrice'] ?? labour);
      // MATERIALS ONLY: don't show extra 0, show parts total
      if (isMaterialsOnly) {
        return FundiWaitingState(
          type: FundiWaitingType.waitingNewPriceApproval,
          title: 'Waiting for client to buy materials - KES $partsTotal',
          message: 'Materials KES $partsTotal • Waiting for client to buy',
          price: partsTotal,
        );
      }
      int extra = _toInt(
        renego?['acceptedCounterExtraLabor'] ??
            renego?['counterExtraLabor'] ??
            1000,
      );
      return FundiWaitingState(
        type: FundiWaitingType.waitingNewPriceApproval,
        title: 'Waiting for client to buy materials - KES $totalLab',
        message:
            'Client locked extra KES $extra • Total KES $totalLab • Waiting for receipt',
        price: totalLab,
      );
    }
    if (lowStatus == 'awaiting_extra_escrow') {
      // MATERIALS ONLY FIX: never show lock extra 0
      if (isMaterialsOnly) {
        return FundiWaitingState(
          type: FundiWaitingType.waitingNewPriceApproval,
          title: 'Waiting for client to buy materials - KES $partsTotal',
          message: 'Materials only - no extra labour to lock',
          price: partsTotal,
        );
      }
      int extra = _toInt(
        renego?['extraLabor'] ??
            renego?['acceptedCounterExtraLabor'] ??
            renego?['extraToLock'] ??
            job['extraLaborAmount'] ??
            job['extraToLock'] ??
            2000,
      );
      int pureExtra = _toInt(renego?['acceptedCounterExtraLabor'] ?? 0);
      if (pureExtra > 0) extra = pureExtra;
      if (extra == 0) {
        // fallback if extra computed as 0 but hasParts false already handled - treat as materials flow
        return FundiWaitingState(
          type: FundiWaitingType.waitingNewPriceApproval,
          title: 'Waiting for client to buy materials - KES $partsTotal',
          message: 'Waiting for client to buy materials',
          price: partsTotal,
        );
      }
      return FundiWaitingState(
        type: FundiWaitingType.waitingEscrow,
        title: 'Waiting for client to lock extra KES $extra to escrow',
        message: 'You accepted extra KES $extra - waiting for client to lock',
        price: extra,
      );
    }
  }

  if (lowStatus == 'in_progress' ||
      lowStatus == 'fundi_working' ||
      lowPhase == 'fundi_working' ||
      lowPhase == 'in_progress') {
    int totalLab = _toInt(job['agreedPrice'] ?? labour);
    return FundiWaitingState(
      type: FundiWaitingType.working,
      title: 'You are working - KES $totalLab',
      message: 'You are working on this job',
      price: totalLab,
    );
  }
  if (lowStatus == 'pending_completion' ||
      lowStatus == 'job_completed' ||
      lowPhase == 'completed_by_fundi' ||
      lowPhase == 'pending_completion') {
    int totalLab = _toInt(job['agreedPrice'] ?? labour);
    return FundiWaitingState(
      type: FundiWaitingType.jobCompleted,
      title: 'Job Completed - Waiting for client to confirm',
      message: 'Waiting for client to confirm and release payment',
      price: totalLab,
    );
  }

  bool renegoRequested = _toBool(renego?['requested']);
  bool renegoPending =
      renego != null && renegoRequested && renegoStatus == 'pending';
  bool renegoCountered =
      renegoStatus == 'countered_by_client' || renegoStatus == 'countered';

  if (renegoCountered) {
    int requestedExtra = _toInt(
      renego?['counteredExtraRequested'] ?? renego?['extraLabor'] ?? 0,
    );
    int counterExtra = _toInt(renego?['counterExtraLabor'] ?? 0);
    if (counterExtra == 0) {
      int toLock = _toInt(renego?['counterExtraToLock'] ?? 0);
      if (toLock > 0) counterExtra = (toLock / 1.05).round();
    }
    if (counterExtra > labour) counterExtra = counterExtra - labour;
    return FundiWaitingState(
      type: FundiWaitingType.clientCounter,
      title:
          'Client countered your extra KES $requestedExtra to KES $counterExtra',
      message:
          'Client countered extra: KES $counterExtra (you asked KES $requestedExtra)',
      price: counterExtra,
    );
  }
  if (renegoPending) {
    // MATERIALS ONLY FIX: don't show approve extra KES 0
    if (isMaterialsOnly) {
      return FundiWaitingState(
        type: FundiWaitingType.waitingNewPriceApproval,
        title: 'Waiting for client to approve materials - KES $partsTotal',
        message: 'You requested materials KES $partsTotal - no extra labour',
        price: partsTotal,
      );
    }
    int extra = _toInt(
      renego['extraLabor'] ?? renego['pendingLabor'] ?? renego['extra'] ?? 0,
    );
    if (extra == 0) {
      int toLock = _toInt(renego['extraToLock'] ?? 0);
      if (toLock > 0) extra = (toLock / 1.05).round();
    }
    return FundiWaitingState(
      type: FundiWaitingType.waitingNewPriceApproval,
      title: 'Waiting for client to approve extra KES $extra',
      message: 'You requested extra KES $extra',
      price: extra,
    );
  }

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
  if (bidStatus == 'counter_accepted_by_fundi' ||
      jobStatus == 'counter_accepted' ||
      jobStatus == 'counter_accepted_by_fundi') {
    return FundiWaitingState(
      type: FundiWaitingType.waitingEscrow,
      title:
          'Counter offer accepted - Waiting for client to confirm KES $fundiSees',
      message:
          'You accepted KES $fundiSees - waiting for client to confirm and lock escrow',
      price: fundiSees,
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

  int lockedAmount = _toInt(
    job['escrowAmount'] ??
        job['lockedEscrow'] ??
        job['escrowLockedAmount'] ??
        0,
  );
  bool hasLockedAmount = lockedAmount > 0;
  bool needsTopup = hasLockedAmount && fundiSees > lockedAmount;
  // FIX: when clientNeedsToTopup=true, force needsTopup true
  if (_toBool(job['clientNeedsToTopup'])) needsTopup = true;
  if (extraLocked || isInMaterialFlow) needsTopup = false;

  int needExtra = needsTopup ? fundiSees - lockedAmount : 0;

  // FIX: always fallback to renegotiation extra fields
  int newLaborVal = _toInt(renego?['newLabor'] ?? 0);
  int newTotalVal = _toInt(
    renego?['newTotalClientPays'] ?? renego?['newTotal'] ?? 0,
  );

  int pureExtra = _toInt(
    renego?['extraLabor'] ??
        renego?['approvedExtra'] ??
        renego?['counterExtraLabor'] ??
        job['extraLaborAmount'] ??
        0,
  );
  if (pureExtra == 0 && newLaborVal > 0) {
    pureExtra = newLaborVal - labour;
  }

  int toLockExtra = _toInt(
    job['extraToLock'] ??
        job['extraEscrowAmount'] ??
        job['extraTopupToLock'] ??
        renego?['extraToLock'] ??
        0,
  );
  if (toLockExtra == 0 && newTotalVal > 0) {
    toLockExtra = newTotalVal - lockedAmount;
  }

  if (pureExtra > 0) {
    needExtra = pureExtra;
  } else if (toLockExtra > 0)
    needExtra = (toLockExtra / 1.05).round(); // 2100 -> 2000
  else if (needExtra <= 0)
    needExtra = _toInt(job['extraLaborAmount'] ?? 0);

  bool isInitialEscrowWait =
      !escrowDone &&
      !siteDone &&
      !travelling &&
      !_toBool(job['cancelled']) &&
      !_toBool(job['autoCancelled']) &&
      ['assigned', 'confirmed', 'negotiating', 'accepted'].contains(jobStatus);
  bool isAwaitingExtra =
      jobStatus == 'awaiting_extra_escrow' &&
      !extraLocked &&
      _toBool(job['clientNeedsToTopup']) &&
      !isInMaterialFlow;
  bool isTopupWait =
      needsTopup &&
      !travelling &&
      !renegoPending &&
      !renegoCountered &&
      !extraLocked &&
      !isInMaterialFlow;

  if (isInitialEscrowWait || isTopupWait || isAwaitingExtra) {
    return FundiWaitingState(
      type: FundiWaitingType.waitingEscrow,
      title: isTopupWait || isAwaitingExtra
          ? 'Waiting for client to lock extra KES $needExtra to escrow'
          : 'Waiting for client to lock KES $fundiSees to escrow',
      message: isTopupWait || isAwaitingExtra
          ? 'Waiting for client to lock extra KES $needExtra'
          : 'Waiting for client to lock KES $fundiSees',
      price: isTopupWait || isAwaitingExtra ? needExtra : fundiSees,
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

  if (bidStatus == 'pending' || bidStatus == 'sent' || bidStatus == '') {
    int hasAgreed = _toInt(
      job['agreedPrice'] ??
          job['acceptedBidAmount'] ??
          job['fundiBidAmount'] ??
          0,
    );
    int hasEscrow = _toInt(
      job['escrowAmount'] ??
          job['lockedEscrow'] ??
          job['escrowLockedAmount'] ??
          0,
    );
    if (hasAgreed > 0 || hasEscrow > 0 || escrowDone || siteDone || travelling)
      return null;
    int p = _toInt(bid['price'] ?? bid['amount'] ?? bid['bidPrice'] ?? labour);
    if (p == 0) p = _toInt(job['agreedPrice'] ?? 6000);
    return FundiWaitingState(
      type: FundiWaitingType.bidSent,
      title: 'Bid sent - KES $p - Waiting for client to react',
      message: 'You sent KES $p',
      price: p,
    );
  }
  return null;
}
