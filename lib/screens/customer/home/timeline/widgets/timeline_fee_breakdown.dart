import 'package:flutter/material.dart';
import '../timeline_utils.dart';

class FeeBreakdown extends StatelessWidget {
  final int labour;
  final int transport;
  final String transportLabel;
  final int clientAppFee;
  final int totalToPay;
  final bool showTotalBold;

  const FeeBreakdown({
    super.key,
    required this.labour,
    required this.transport,
    required this.transportLabel,
    required this.clientAppFee,
    required this.totalToPay,
    this.showTotalBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        feeRow('Fundi labour charges:', 'KES $labour'),
        feeRow(transportLabel, 'KES $transport'),
        feeRow('App maintenance cost:', 'KES $clientAppFee'),
        const Divider(height: 10),
        feeRow('Total to pay:', 'KES $totalToPay', bold: showTotalBold),
      ],
    );
  }
}

class ReleaseFeeBreakdown extends StatelessWidget {
  final int labour;
  final int transport;
  final int clientFee;
  final int total;

  const ReleaseFeeBreakdown({
    super.key,
    required this.labour,
    required this.transport,
    required this.clientFee,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        feeRow('Labour:', 'KES $labour'),
        feeRow('Transport:', 'KES $transport'),
        feeRow('App Maintenance cost 5%:', 'KES $clientFee'),
        const Divider(height: 6),
        feeRow('Total you release:', 'KES $total', bold: true),
      ],
    );
  }
}
