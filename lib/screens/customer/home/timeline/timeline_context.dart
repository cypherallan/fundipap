import 'package:flutter/material.dart';
import 'timeline_utils.dart';

class TimelineContext {
  final Map<String, dynamic> job;
  final String fundiName;
  final String trade;
  final String jobId;
  final BuildContext context;
  final bool releasing;
  final Function(bool) onReleasing;

  final String escrow;
  final String status;
  final String location;
  final bool siteDone;
  final bool isTravelling;
  final Map<String, dynamic>? reneg;
  final String renegStatus;
  final String phase;
  final bool needsExtraEscrow;

  final int labour;
  final int transport;
  final double km;
  final String mode;
  final String transportLabel;
  final int clientAppFee;
  final int fundiAppFee;
  final int totalToPay;
  final double agreed;
  final int alreadyLocked;
  final bool escrowHeldFlag;
  final bool escrowDone;
  final bool clientRated;
  final String fundiId;
  final String fundiNameStr;

  TimelineContext({
    required this.job,
    required this.fundiName,
    required this.trade,
    required this.jobId,
    required this.context,
    required this.releasing,
    required this.onReleasing,
    required this.escrow,
    required this.status,
    required this.location,
    required this.siteDone,
    required this.isTravelling,
    required this.reneg,
    required this.renegStatus,
    required this.phase,
    required this.needsExtraEscrow,
    required this.labour,
    required this.transport,
    required this.km,
    required this.mode,
    required this.transportLabel,
    required this.clientAppFee,
    required this.fundiAppFee,
    required this.totalToPay,
    required this.agreed,
    required this.alreadyLocked,
    required this.escrowHeldFlag,
    required this.escrowDone,
    required this.clientRated,
    required this.fundiId,
    required this.fundiNameStr,
  });

  factory TimelineContext.fromJob({
    required Map<String, dynamic> job,
    required String fundiName,
    required String trade,
    required String jobId,
    required BuildContext context,
    required bool releasing,
    required Function(bool) onReleasing,
  }) {
    var escrow = (job['escrowStatus'] ?? 'pending').toString();
    var status = (job['status'] ?? '').toString();
    var location = (job['location'] ?? job['address'] ?? 'Your location')
        .toString();
    bool siteDone = toBool(job['siteVisitDone']) || toBool(job['siteVisited']);
    bool isTravelling =
        toBool(job['travelling']) &&
        toBool(job['siteVisitStarted']) &&
        !siteDone;
    var reneg = job['renegotiation'] as Map<String, dynamic>?;
    String renegStatus = (reneg?['status'] ?? '').toString();
    String phase = (reneg?['currentPhase'] ?? '').toString();
    bool needsExtraEscrow = renegStatus.contains('pending_extra_escrow');

    // FIX: labour is final countered amount (5000), transport defaults 100 not 0
    int labour = toInt(
      job['laborCost'] ??
          job['agreedPrice'] ??
          job['acceptedBidAmount'] ??
          job['lastCounterAmount'] ??
          0,
    );
    int transport = toInt(job['transportFee'] ?? 100); // FIX: was 0 -> now 100
    double km = toDouble(job['transportDistanceKm'] ?? 0);
    String mode = (job['transportMode'] ?? 'boda').toString();
    String transportLabel = km > 0
        ? 'Transport cost ($mode ${km.toStringAsFixed(1)}km):'
        : 'Transport cost ($mode):';
    int clientAppFee = toInt(job['clientAppFee'] ?? (labour * 0.05).round());
    int fundiAppFee = toInt(job['fundiAppFee'] ?? (labour * 0.05).round());
    // FIX: use saved totalClientPays if exists (5350), else calc with transport
    int totalToPay = toInt(
      job['totalClientPays'] ??
          job['totalCost'] ??
          labour + transport + clientAppFee,
    );
    double agreed = totalToPay.toDouble();
    int alreadyLocked = toInt(job['escrowAmount'] ?? 0);
    bool escrowHeldFlag =
        toBool(job['escrowHeld']) || job['escrowPaidAt'] != null;
    bool escrowDone =
        ['held', 'paid', 'released'].contains(escrow) ||
        escrowHeldFlag ||
        alreadyLocked > 0 ||
        status == 'escrow_locked' ||
        status == 'completed';
    bool clientRated = toBool(job['clientRated']);
    String fundiId =
        (job['fundiId'] ?? job['assignedFundiId'] ?? job['acceptedBidId'] ?? '')
            .toString();
    String fundiNameStr =
        (job['assignedFundiName'] ?? job['fundiName'] ?? 'your fundi')
            .toString();

    return TimelineContext(
      job: job,
      fundiName: fundiName,
      trade: trade,
      jobId: jobId,
      context: context,
      releasing: releasing,
      onReleasing: onReleasing,
      escrow: escrow,
      status: status,
      location: location,
      siteDone: siteDone,
      isTravelling: isTravelling,
      reneg: reneg,
      renegStatus: renegStatus,
      phase: phase,
      needsExtraEscrow: needsExtraEscrow,
      labour: labour,
      transport: transport,
      km: km,
      mode: mode,
      transportLabel: transportLabel,
      clientAppFee: clientAppFee,
      fundiAppFee: fundiAppFee,
      totalToPay: totalToPay,
      agreed: agreed,
      alreadyLocked: alreadyLocked,
      escrowHeldFlag: escrowHeldFlag,
      escrowDone: escrowDone,
      clientRated: clientRated,
      fundiId: fundiId,
      fundiNameStr: fundiNameStr,
    );
  }
}
