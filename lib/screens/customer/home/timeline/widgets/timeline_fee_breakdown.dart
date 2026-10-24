import 'package:flutter/material.dart';
import '../timeline_utils.dart';

class FeeBreakdown extends StatelessWidget {
  final int labour;
  final int transport;
  final String transportLabel;
  final int clientAppFee;
  final int totalToPay;
  final bool showTotalBold;
  final int? oldLaborLocked;
  final int? extraRequested;

  const FeeBreakdown({
    super.key,
    required this.labour,
    required this.transport,
    required this.transportLabel,
    required this.clientAppFee,
    required this.totalToPay,
    this.showTotalBold = false,
    this.oldLaborLocked,
    this.extraRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasExtra =
        extraRequested != null &&
        extraRequested! > 0 &&
        oldLaborLocked != null &&
        oldLaborLocked! > 0;
    return Column(
      children: [
        if (hasExtra) feeRow('Old labor locked:', 'KES $oldLaborLocked'),
        if (hasExtra)
          feeRow('New extra labour requested:', 'KES $extraRequested'),
        if (!hasExtra) feeRow('Fundi labour charges:', 'KES $labour'),
        feeRow(transportLabel, 'KES $transport'),
        feeRow('App maintenance cost:', 'KES $clientAppFee'),
        const Divider(height: 10),
        feeRow(
          hasExtra ? 'Total to lock now:' : 'Total to pay:',
          'KES $totalToPay',
          bold: showTotalBold || hasExtra,
        ),
      ],
    );
  }
}

class ReleaseFeeBreakdown extends StatelessWidget {
  final int labour;
  final int transport;
  final int clientFee;
  final int total;
  final int? oldLaborLocked;
  final int? extraRequested;

  const ReleaseFeeBreakdown({
    super.key,
    required this.labour,
    required this.transport,
    required this.clientFee,
    required this.total,
    this.oldLaborLocked,
    this.extraRequested,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasExtra =
        extraRequested != null &&
        extraRequested! > 0 &&
        oldLaborLocked != null &&
        oldLaborLocked! > 0;
    return Column(
      children: [
        if (hasExtra) feeRow('Old labor locked:', 'KES $oldLaborLocked'),
        if (hasExtra) feeRow('Extra labour:', 'KES $extraRequested'),
        feeRow(
          hasExtra ? 'Total Labour (old+extra):' : 'Labour:',
          'KES $labour',
        ),
        feeRow('Transport:', 'KES $transport'),
        feeRow('App Maintenance cost 5%:', 'KES $clientFee'),
        const Divider(height: 6),
        feeRow('Total you release:', 'KES $total', bold: true),
      ],
    );
  }
}
