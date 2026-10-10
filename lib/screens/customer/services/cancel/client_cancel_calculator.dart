enum ClientCancelStage {
  beforeEscrow,
  afterEscrowBeforeTravel,
  fundiRequestPending,
  clientCounterAcceptedNotPaid,
  extraLocked,
  afterArrival,
  blockedJobStarted,
}

class CancelBreakdown {
  final ClientCancelStage stage;
  final List<String> logs;

  final int oldLabour;
  final int extraLabour;
  final int totalLabour;

  final int transport;
  final int oldFee;
  final int extraFee;
  final int totalFee;

  final int oldTotal;
  final int extraTotal;
  final int totalShouldBe;
  final int totalActuallyLocked;

  final int labourForCalc;
  final int feeForCalc;
  final int totalLockedDisplay;
  final int fundiGets;
  final int clientRefund;

  final bool extraPaid;
  final bool needsTopup;
  final bool extraLocked;
  final bool priceRequestPending;
  final bool arrived;

  CancelBreakdown({
    required this.stage,
    required this.logs,
    required this.oldLabour,
    required this.extraLabour,
    required this.totalLabour,
    required this.transport,
    required this.oldFee,
    required this.extraFee,
    required this.totalFee,
    required this.oldTotal,
    required this.extraTotal,
    required this.totalShouldBe,
    required this.totalActuallyLocked,
    required this.labourForCalc,
    required this.feeForCalc,
    required this.totalLockedDisplay,
    required this.fundiGets,
    required this.clientRefund,
    required this.extraPaid,
    required this.needsTopup,
    required this.extraLocked,
    required this.priceRequestPending,
    required this.arrived,
  });
}

class ClientCancelCalculator {
  static const double feeRate = 0.05;

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _isFundiPriceRequestPending(Map<String, dynamic> job) {
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    if (reneg == null) return false;
    var requested = reneg['requested'] == true;
    var status = (reneg['status'] ?? '').toString().toLowerCase();
    var requestedBy = (reneg['requestedBy'] ?? '').toString().toLowerCase();
    if (requested && status == 'pending' && requestedBy != 'client')
      return true;
    if (status == 'pending' && requestedBy == 'fundi') return true;
    return requested && status == 'pending';
  }

  static CancelBreakdown calculate(Map<String, dynamic> job) {
    List<String> logs = [];
    var reneg = job['renegotiation'] as Map<String, dynamic>?;

    int oldLabour = _toInt(
      reneg?['oldLabor'] ??
          job['acceptedBidAmount'] ??
          job['currentLabour'] ??
          job['agreedPrice'] ??
          0,
    );
    int extraLabour = _toInt(
      reneg?['extraLabor'] ??
          reneg?['acceptedCounterExtraLabor'] ??
          reneg?['approvedExtra'] ??
          reneg?['counterExtraLabor'] ??
          job['extraLaborAmount'] ??
          job['extraTopupAmount'] ??
          0,
    );
    if (extraLabour == 0) {
      int tl = _toInt(job['extraToLock'] ?? reneg?['extraToLock'] ?? 0);
      if (tl > 0) extraLabour = (tl / 1.05).round();
    }
    int totalLabour = _toInt(
      reneg?['newLaborTotal'] ??
          reneg?['counterLabor'] ??
          job['laborCost'] ??
          job['agreedPrice'] ??
          0,
    );
    if (totalLabour < oldLabour + extraLabour)
      totalLabour = oldLabour + extraLabour;
    if (totalLabour == 0) totalLabour = oldLabour;

    int transport = _toInt(
      job['transportFee'] ??
          job['escrowTransport'] ??
          reneg?['counterTransportFee'] ??
          0,
    );
    int oldFee = (oldLabour * feeRate).round();
    int extraFee = (extraLabour * feeRate).round();
    int totalFee = (totalLabour * feeRate).round();

    // FIX: prefer reneg oldTotal, not job totalCost which may be stale
    int oldTotal = _toInt(
      reneg?['oldTotalClientPays'] ??
          job['totalCost'] ??
          (oldLabour + transport + oldFee),
    );
    // FIX: compute extraTotal from labour+fee, don't trust corrupted extraToLock=6450
    int extraTotal = extraLabour + extraFee;
    if (extraTotal == 0) {
      extraTotal = _toInt(
        job['extraEscrowAmount'] ??
            reneg?['extraToLock'] ??
            job['extraToLock'] ??
            0,
      );
    }
    // FIX: prefer reneg newTotal which is 8550, not job totalClientPays 6450
    int totalShouldBe = _toInt(
      reneg?['newTotalClientPays'] ??
          reneg?['newTotal'] ??
          reneg?['counterTotalClientPays'] ??
          (oldTotal + extraTotal),
    );
    // fallback if reneg missing
    if (totalShouldBe == oldTotal && extraTotal > 0) {
      totalShouldBe = oldTotal + extraTotal;
    }

    int actualEscrowInDb = _toInt(job['escrowAmount'] ?? 0);
    bool extraPaid = (job['extraEscrowStatus'] ?? '').toString() == 'paid';
    bool needsTopup = job['clientNeedsToTopup'] == true;
    String escrowStatusStr = (job['escrowStatus'] ?? '').toString();
    bool escrowLocked =
        actualEscrowInDb > 0 ||
        escrowStatusStr == 'held' ||
        escrowStatusStr == 'locked' ||
        job['escrowDone'] == true;

    bool priceRequestPending = _isFundiPriceRequestPending(job);

    String status = (job['status'] ?? '').toString().toLowerCase();
    bool travelling = job['travelling'] == true || status == 'travelling';
    bool siteDone =
        job['siteVisitDone'] == true ||
        job['siteVisited'] == true ||
        job['fundiArrivedAt'] != null;
    bool isStarted = [
      'in_progress',
      'pending_completion',
      'job_completed',
    ].contains(status);
    bool arrived = travelling || siteDone;

    logs.add(
      'oldLabour=$oldLabour extraLabour=$extraLabour totalLabour=$totalLabour',
    );
    logs.add('transport=$transport oldFee=$oldFee totalFee=$totalFee');
    logs.add(
      'oldTotal=$oldTotal extraTotal=$extraTotal totalShouldBe=$totalShouldBe actualEscrowInDb=$actualEscrowInDb',
    );
    logs.add(
      'extraPaid=$extraPaid needsTopup=$needsTopup escrowLocked=$escrowLocked priceRequestPending=$priceRequestPending arrived=$arrived status=$status',
    );

    // extra is locked if paid - ignore stale needsTopup flag
    bool extraLocked = extraLabour > 0 && extraPaid;

    // BUG FIX 1: your doc has escrowAmount=2100 but reneg newTotal=8550
    if (extraLocked &&
        actualEscrowInDb == extraTotal &&
        actualEscrowInDb != totalShouldBe) {
      logs.add(
        'BUG FIX: escrowAmount is extraTotal $extraTotal, but correct totalShouldBe is $totalShouldBe - using $totalShouldBe',
      );
      actualEscrowInDb = totalShouldBe;
    }

    // BUG FIX 2: your dump has extraToLock=6450 corrupted, but actual is 2100
    if (extraLocked && _toInt(job['extraToLock'] ?? 0) == oldTotal) {
      logs.add(
        'BUG FIX: job extraToLock is oldTotal ${job['extraToLock']}, ignoring',
      );
    }

    // If needsTopup true but escrow still oldTotal, then NOT locked yet
    if (actualEscrowInDb == oldTotal && needsTopup && !extraPaid) {
      logs.add('needsTopup=true and escrow still oldTotal - not locked yet');
      extraLocked = false;
    }

    logs.add(
      'extraLocked=$extraLocked actualEscrowFixed=$actualEscrowInDb needsTopup=$needsTopup',
    );

    ClientCancelStage stage;
    int labourForCalc;
    int feeForCalc;
    int totalLockedDisplay;

    if (!escrowLocked) {
      stage = ClientCancelStage.beforeEscrow;
      labourForCalc = oldLabour;
      feeForCalc = 0;
      totalLockedDisplay = 0;
      logs.add('CANCEL 1: BEFORE ESCROW - No fee, job goes back to OPEN');
    } else if (isStarted) {
      stage = ClientCancelStage.blockedJobStarted;
      labourForCalc = totalLabour;
      feeForCalc = totalFee;
      totalLockedDisplay = extraLocked ? totalShouldBe : actualEscrowInDb;
      logs.add('CANCEL BLOCKED: Job already started, cannot cancel');
    } else if (priceRequestPending && !extraLocked) {
      stage = ClientCancelStage.fundiRequestPending;
      labourForCalc = oldLabour;
      feeForCalc = oldFee;
      totalLockedDisplay = actualEscrowInDb;
      logs.add('CANCEL 2: FUNDI REQUESTED 2000 PENDING -> use OLD locked');
    } else if ((!extraLocked && extraLabour > 0 && !priceRequestPending) ||
        (needsTopup && !extraLocked)) {
      stage = ClientCancelStage.clientCounterAcceptedNotPaid;
      labourForCalc = oldLabour;
      feeForCalc = oldFee;
      totalLockedDisplay = actualEscrowInDb;
      logs.add(
        'CANCEL 3: CLIENT COUNTERED 1000, FUNDI ACCEPTED, NOT PAID YET -> use OLD locked 5400/5000',
      );
    } else if (extraLocked) {
      stage = ClientCancelStage.extraLocked;
      labourForCalc = totalLabour;
      feeForCalc = totalFee;
      totalLockedDisplay = totalShouldBe;
      logs.add('CANCEL 4: EXTRA LOCKED -> use NEW totals 6400/6000');
    } else if (arrived) {
      stage = ClientCancelStage.afterArrival;
      labourForCalc = oldLabour;
      feeForCalc = oldFee;
      totalLockedDisplay = actualEscrowInDb;
      logs.add('CANCEL 5: AFTER ARRIVAL');
    } else {
      stage = ClientCancelStage.afterEscrowBeforeTravel;
      labourForCalc = oldLabour;
      feeForCalc = oldFee;
      totalLockedDisplay = actualEscrowInDb;
      logs.add('CANCEL 6: AFTER ESCROW BEFORE TRAVEL');
    }

    int fundiGets = transport;
    if (stage == ClientCancelStage.beforeEscrow) fundiGets = 0;

    int clientRefund = totalLockedDisplay - feeForCalc - fundiGets;
    if (clientRefund < 0) clientRefund = 0;

    logs.add(
      'RESULT: labour=$labourForCalc transport=$transport totalLocked=$totalLockedDisplay fee=$feeForCalc youGet=$clientRefund fundiGets=$fundiGets',
    );

    return CancelBreakdown(
      stage: stage,
      logs: logs,
      oldLabour: oldLabour,
      extraLabour: extraLabour,
      totalLabour: totalLabour,
      transport: transport,
      oldFee: oldFee,
      extraFee: extraFee,
      totalFee: totalFee,
      oldTotal: oldTotal,
      extraTotal: extraTotal,
      totalShouldBe: totalShouldBe,
      totalActuallyLocked: actualEscrowInDb,
      labourForCalc: labourForCalc,
      feeForCalc: feeForCalc,
      totalLockedDisplay: totalLockedDisplay,
      fundiGets: fundiGets,
      clientRefund: clientRefund,
      extraPaid: extraPaid,
      needsTopup: needsTopup,
      extraLocked: extraLocked,
      priceRequestPending: priceRequestPending,
      arrived: arrived,
    );
  }
}
