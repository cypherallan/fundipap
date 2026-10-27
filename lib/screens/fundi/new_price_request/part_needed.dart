import 'package:flutter/material.dart';

class PartNeeded {
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController model = TextEditingController();
  final TextEditingController estPrice = TextEditingController(text: '0');

  void dispose() {
    name.dispose();
    qty.dispose();
    model.dispose();
    estPrice.dispose();
  }

  bool get hasName => name.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
    'name': name.text.trim(),
    'qty': int.tryParse(qty.text) ?? 1,
    'model': model.text.trim(),
    'estPrice': int.tryParse(estPrice.text) ?? 0,
  };
}
