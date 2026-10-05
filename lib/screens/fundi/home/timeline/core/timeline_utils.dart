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

// NEW: Check if materials/parts were checked during extra price request
bool hasPartsInRenego(Map<String, dynamic>? renego) {
  if (renego == null) return false;
  var list = renego['partsNeeded'] as List?;
  if (list != null && list.isNotEmpty) return true;
  int est = toInt(renego['partsEstimateTotal']);
  String till = (renego['tillNumber'] ?? '').toString().trim();
  int total = toInt(renego['totalPartsEstimate']);
  return est > 0 || total > 0 || till.isNotEmpty;
}

bool isNoPartsFlow(Map<String, dynamic>? renego) {
  return !hasPartsInRenego(renego);
}
