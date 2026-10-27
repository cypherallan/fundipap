import 'part_needed.dart';

class PriceCalculator {
  final Map<String, dynamic> job;
  final int fundiFeePct;
  final int clientFeePct;
  final int extraLabor;
  final bool needsLabor;
  final bool needsParts;
  final List<PartNeeded> partsNeeded;

  PriceCalculator({
    required this.job,
    required this.fundiFeePct,
    required this.clientFeePct,
    required this.extraLabor,
    required this.needsLabor,
    required this.needsParts,
    required this.partsNeeded,
  });

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  int get oldLabor =>
      _toInt(job['laborCost'] ?? job['agreedPrice'] ?? job['budget'] ?? 0);

  int get transport =>
      _toInt(job['transportFee'] ?? job['escrowTransport'] ?? 0);

  int get effectiveExtraLabor => needsLabor ? extraLabor : 0;

  int get newLaborTotal => oldLabor + effectiveExtraLabor;

  int get oldClientFee => (oldLabor * clientFeePct / 100).round();

  int get newClientFee => (newLaborTotal * clientFeePct / 100).round();

  int get newFundiFee => (newLaborTotal * fundiFeePct / 100).round();

  int get oldTotalClient => _toInt(
    job['totalClientPays'] ??
        job['totalCost'] ??
        oldLabor + transport + oldClientFee,
  );

  int get newTotalClient => newLaborTotal + transport + newClientFee;

  int get newFundiReceives => newLaborTotal - newFundiFee + transport;

  int get extraToLock => newTotalClient - oldTotalClient;

  int get partsEstimateTotal {
    if (!needsParts) return 0;
    int total = 0;
    for (final p in partsNeeded) {
      if (!p.hasName) continue;
      final qty = int.tryParse(p.qty.text) ?? 1;
      final price = int.tryParse(p.estPrice.text) ?? 0;
      total += qty * price;
    }
    return total;
  }
}
