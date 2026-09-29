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
  final bool isBidSent; // NEW

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
      job['transportFee'] ?? reneg?['oldTransportFee'] ?? 0,
    );
    int labour = newLabour;
    int fundiAppFee = (labour * 0.05).round();
    int fundiReceives = labour - fundiAppFee + transport;
    int fundiSeesWaiting = labour + transport;
    int newTotalFundiLocked = newLabour + transport;
    int newFundiReceivesVal = fundiReceives;
    bool isCounterAccepted = counterExtra > 0;
    int releasedAmount = fundiReceives;

    int storedPayout = toInt(
      job['fundiPayoutAmount'] ?? job['fundiReceives'] ?? 0,
    );
    if (storedPayout > 0 && (storedPayout - fundiReceives).abs() > 500) {
      releasedAmount = fundiReceives;
    } else if (storedPayout > 0) {
      releasedAmount = storedPayout;
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
      fundiReceives: fundiReceives,
      fundiSeesWaiting: fundiSeesWaiting,
      newTotalFundiLocked: newTotalFundiLocked,
      newFundiReceivesVal: newFundiReceivesVal,
      isCounterAccepted: isCounterAccepted,
      releasedAmount: releasedAmount,
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
    );
  }
}
