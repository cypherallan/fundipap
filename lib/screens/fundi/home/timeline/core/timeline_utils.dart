import 'package:cloud_firestore/cloud_firestore.dart';

int toInt(dynamic v, [int fb = 0]) {
  if (v == null) return fb;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is num) return v.toInt();
  try {
    return int.parse(
      v.toString().split('.').first.replaceAll(RegExp(r'[^0-9-]'), ''),
    );
  } catch (_) {
    return fb;
  }
}

bool toBool(dynamic v, [bool fb = false]) {
  if (v == null) return fb;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) {
    var l = v.toLowerCase();
    return l == 'true' || l == '1';
  }
  if (v is Timestamp) return true;
  return fb;
}
