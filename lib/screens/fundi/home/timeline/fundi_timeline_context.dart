import 'package:flutter/material.dart';
import 'fundi_timeline_utils.dart';

class FundiTimelineContext {
  final BuildContext context;
  final String jobId;
  final String clientName;
  final String jobTitle;
  final Map<String, dynamic> job;
  final Map<String, dynamic>? reneg;

  final String status;
  final String escrowStatus;
  final String phase;
  final String renegStatus;

  final int rawExtra;
  final int counterExtra;
  final int extraLabour;
  final int oldLabour;
  final int newLabour;
  final int labour;
  final int transport;
  final int fundiAppFee;
  final int fundiReceives;
  final int fundiSeesWaiting;
  final int newTotalFundiLocked;
  final int newFundiReceivesVal;
  final bool isCounterAccepted;
  final int releasedAmount;

  final bool escrowDone;
  final bool escrowReleased;
  final bool siteDone;
  final bool travelling;
  final bool extraPaid;
  final bool isStarted;
  final bool isCancelled;
  final bool canFundiCancel;
  final bool fundiConfirmedPayment;
  final bool fundiRatedClient;
  final String clientId;
  final bool isBidSent;

  // NEW: deduction from repeat job dispute
  final double? deductionThisJob;
  final double? originalReleasedAmount;
  final double? deductionRemaining;
  final String? deductionDisputeId;
  final String? deductionReason;

  FundiTimelineContext({
    required this.context,
    required this.jobId,
    required this.clientName,
    required this.jobTitle,
    required this.job,
    required this.reneg,
    required this.status,
    required this.escrowStatus,
    required this.phase,
    required this.renegStatus,
    required this.rawExtra,
    required this.counterExtra,
    required this.extraLabour,
    required this.oldLabour,
    required this.newLabour,
    required this.labour,
    required this.transport,
    required this.fundiAppFee,
    required this.fundiReceives,
    required this.fundiSeesWaiting,
    required this.newTotalFundiLocked,
    required this.newFundiReceivesVal,
    required this.isCounterAccepted,
    required this.releasedAmount,
    required this.escrowDone,
    required this.escrowReleased,
    required this.siteDone,
    required this.travelling,
    required this.extraPaid,
    required this.isStarted,
    required this.isCancelled,
    required this.canFundiCancel,
    required this.fundiConfirmedPayment,
    required this.fundiRatedClient,
    required this.clientId,
    required this.isBidSent,
    this.deductionThisJob,
    this.originalReleasedAmount,
    this.deductionRemaining,
    this.deductionDisputeId,
    this.deductionReason,
  });

  factory FundiTimelineContext.fromSnapshot({
    required BuildContext context,
    required String jobId,
    required String clientName,
    required String jobTitle,
    required Map<String, dynamic> job,
  }) {
    var status = (job['status'] ?? '').toString();
    var escrow = (job['escrowStatus'] ?? 'pending').toString();
    bool escrowDone =
        escrow == 'held' || escrow == 'paid' || escrow == 'released';
    bool escrowReleased = escrow == 'released' || status == 'completed';

    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    String phase = (reneg?['currentPhase'] ?? '').toString();
    String rs = (reneg?['status'] ?? '').toString();

    int rawExtra = toInt(reneg?['extraLabor'] ?? job['extraLaborAmount'] ?? 0);
    int counterExtra = toInt(
      reneg?['acceptedCounterExtraLabor'] ?? reneg?['counterExtraLabor'] ?? 0,
    );
    int extraLabour = counterExtra > 0 ? counterExtra : rawExtra;

    int oldLabour = toInt(reneg?['oldLabor'] ?? 0);
    if (oldLabour == 0) {
      int fromJob = toInt(job['laborCost'] ?? job['agreedPrice'] ?? 0);
      oldLabour = fromJob > extraLabour ? fromJob - extraLabour : 5000;
      if (oldLabour <= 0) oldLabour = 5000;
    }

    int newLabour = oldLabour + extraLabour;
    if (newLabour <= 0) newLabour = toInt(job['laborCost'] ?? 5000);

    int transport = toInt(
      job['transportFee'] ?? reneg?['oldTransportFee'] ?? 183,
    );
    int labour = newLabour;

    String badgeLevel =
        (job['fundiBadgeLevel'] ??
                job['badgeLevel'] ??
                job['fundiBadge'] ??
                'none')
            .toString()
            .toLowerCase();
    bool isTrialGold =
        job['isTrialGold'] == true ||
        job['fundiIsTrialGold'] == true ||
        job['isTrial'] == true;

    int fundiPct;
    if (isTrialGold) {
      fundiPct = 5;
    } else if (badgeLevel == 'gold')
      fundiPct = 5;
    else if (badgeLevel == 'silver')
      fundiPct = 8;
    else if (badgeLevel == 'bronze')
      fundiPct = 10;
    else
      fundiPct = 15;

    int fundiAppFee = (labour * fundiPct / 100).round();
    int baseFundiReceives = labour - fundiAppFee + transport;
    int fundiSeesWaiting = labour + transport;
    int newTotalFundiLocked = newLabour + transport;
    int newFundiReceivesVal =
        newLabour - (newLabour * fundiPct / 100).round() + transport;
    bool isCounterAccepted = counterExtra > 0;

    // DEDUCTION LOGIC - check if this payout has 50% deduction from repeat job
    double deduction = (job['deductionThisJob'] ?? 0).toDouble();
    double originalAmount = (job['originalReleasedAmount'] ?? baseFundiReceives)
        .toDouble();
    double remainingAfter = (job['deductionRemainingAfter'] ?? 0).toDouble();
    String? disputeId = job['deductionDisputeId']?.toString();
    double payoutAfterDeduction =
        (job['fundiPayoutAfterDeduction'] ?? (baseFundiReceives - deduction))
            .toDouble();

    int finalFundiReceives;
    int finalReleasedAmount;
    double? finalOriginal;
    double? finalRemaining;

    if (deduction > 0) {
      finalFundiReceives = payoutAfterDeduction.round();
      finalReleasedAmount = payoutAfterDeduction.round();
      finalOriginal = originalAmount;
      finalRemaining = remainingAfter;
    } else {
      finalFundiReceives = baseFundiReceives;
      finalReleasedAmount = baseFundiReceives;
      finalOriginal = null;
      finalRemaining = null;
    }

    bool siteDone = toBool(job['siteVisitDone']) || toBool(job['siteVisited']);
    bool travelling = toBool(job['travelling']) || status == 'travelling';
    bool extraPaid = (job['extraEscrowStatus'] ?? '') == 'paid';
    bool isStarted =
        status == 'in_progress' ||
        phase == 'fundi_working' ||
        status == 'job_completed' ||
        status == 'pending_completion' ||
        status == 'completed';
    bool isCancelled = status.toLowerCase().contains('cancel');
    bool canFundiCancel =
        (status == 'assigned' || status == 'confirmed') &&
        !travelling &&
        !siteDone &&
        !isStarted &&
        !isCancelled;

    bool fundiConfirmedPayment = toBool(job['fundiConfirmedPayment']);
    bool fundiRatedClient = toBool(job['fundiRated']);
    String clientId = (job['clientId'] ?? job['customerId'] ?? '').toString();
    bool isBidSent =
        status == 'bid_sent' || status == 'pending_client_response';

    String? deductionReason;
    if (deduction > 0 && disputeId != null) {
      String shortId = disputeId.length > 6
          ? disputeId.substring(0, 6)
          : disputeId;
      deductionReason =
          'KES ${deduction.toStringAsFixed(0)} deducted from your pay as a result of dispute $shortId, it will be deducted until client gets a refund of 50% of what was paid to you. Reason: repeat job within 14 days - no redo after 24h + 6h reminder.';
    }

    return FundiTimelineContext(
      context: context,
      jobId: jobId,
      clientName: clientName,
      jobTitle: jobTitle,
      job: job,
      reneg: reneg,
      status: status,
      escrowStatus: escrow,
      phase: phase,
      renegStatus: rs,
      rawExtra: rawExtra,
      counterExtra: counterExtra,
      extraLabour: extraLabour,
      oldLabour: oldLabour,
      newLabour: newLabour,
      labour: labour,
      transport: transport,
      fundiAppFee: fundiAppFee,
      fundiReceives: finalFundiReceives,
      fundiSeesWaiting: fundiSeesWaiting,
      newTotalFundiLocked: newTotalFundiLocked,
      newFundiReceivesVal: newFundiReceivesVal,
      isCounterAccepted: isCounterAccepted,
      releasedAmount: finalReleasedAmount,
      escrowDone: escrowDone,
      escrowReleased: escrowReleased,
      siteDone: siteDone,
      travelling: travelling,
      extraPaid: extraPaid,
      isStarted: isStarted,
      isCancelled: isCancelled,
      canFundiCancel: canFundiCancel,
      fundiConfirmedPayment: fundiConfirmedPayment,
      fundiRatedClient: fundiRatedClient,
      clientId: clientId,
      isBidSent: isBidSent,
      deductionThisJob: deduction > 0 ? deduction : null,
      originalReleasedAmount: finalOriginal,
      deductionRemaining: finalRemaining,
      deductionDisputeId: disputeId,
      deductionReason: deductionReason,
    );
  }
}
