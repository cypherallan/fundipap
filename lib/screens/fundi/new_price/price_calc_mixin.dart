import 'package:flutter/material.dart';
import 'fundi_request_new_price_screen.dart';

mixin PriceCalcMixin on State<FundiRequestNewPriceScreen> {
  int toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  bool get needsParts =>
      (this as dynamic).selectedReasons.contains(
        'New parts / materials needed',
      ) ||
      (this as dynamic).selectedReasons.contains(
        'Replacement needed (old part damaged)',
      );
  bool get needsLabor =>
      (this as dynamic).selectedReasons.contains(
        'Job bigger / more work than expected',
      ) ||
      (this as dynamic).selectedReasons.contains('Extra labor required') ||
      (this as dynamic).selectedReasons.contains('Transport / distance extra');

  int get oldLabor => toInt(
    widget.job['laborCost'] ??
        widget.job['agreedPrice'] ??
        widget.job['budget'] ??
        0,
  );
  int get transport =>
      toInt(widget.job['transportFee'] ?? widget.job['escrowTransport'] ?? 0);
  int get extraLabor =>
      needsLabor ? toInt((this as dynamic).extraLaborCtrl.text) : 0;
  int get newLaborTotal => oldLabor + extraLabor;
  int get oldClientFee =>
      (oldLabor * (this as dynamic).clientFeePct / 100).round();
  int get newClientFee =>
      (newLaborTotal * (this as dynamic).clientFeePct / 100).round();
  int get newFundiFee =>
      (newLaborTotal * (this as dynamic).fundiFeePct / 100).round();
  int get oldTotalClient => toInt(
    widget.job['totalClientPays'] ??
        widget.job['totalCost'] ??
        oldLabor + transport + oldClientFee,
  );
  int get newTotalClient => newLaborTotal + transport + newClientFee;
  int get newFundiReceives => newLaborTotal - newFundiFee + transport;
  int get extraToLock => newTotalClient - oldTotalClient;

  int get partsEstimateTotal {
    if (!needsParts) return 0;
    int total = 0;
    for (var p in (this as dynamic).partsNeeded) {
      if ((p['name']?.text.trim().isEmpty ?? true)) continue;
      int qty = int.tryParse(p['qty']?.text ?? '1') ?? 1;
      int price = int.tryParse(p['estPrice']?.text ?? '0') ?? 0;
      total += qty * price;
    }
    return total;
  }
}
