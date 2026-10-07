import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/fundi_badge_service.dart';

enum FilterType { all, verified, topRated, highReferral, clean, badge, nearby }

class BidWithFundi {
  final QueryDocumentSnapshot bidDoc;
  final Map<String, dynamic> bid;
  final BadgeLevel level;
  final bool verified;
  final int referrals;
  final int jobsDone;
  final double rating;
  final int penalty;
  final double distanceKm;

  BidWithFundi({
    required this.bidDoc,
    required this.bid,
    required this.level,
    required this.verified,
    required this.referrals,
    required this.jobsDone,
    required this.rating,
    required this.penalty,
    required this.distanceKm,
  });
}
