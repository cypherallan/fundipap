import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/customer_home_models.dart';
import '../../helpers/customer_home_utils.dart';
import '../../../../../services/fundi_badge_service.dart';
import 'pending_bid_card.dart';

class PendingBidList extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> job;
  final FilterType filter;
  final Position? userPos;

  const PendingBidList({
    super.key,
    required this.jobId,
    required this.job,
    required this.filter,
    required this.userPos,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .snapshots(),
      builder: (_, bSnap) {
        if (!bSnap.hasData) return const LinearProgressIndicator();
        if (bSnap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.black26),
                const SizedBox(height: 6),
                Text(
                  'Waiting for fundis to bid',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          );
        }
        return FutureBuilder<List<BidWithFundi>>(
          future: enrichBids(bSnap.data!.docs, userPos),
          builder: (_, s) {
            if (!s.hasData) return const LinearProgressIndicator();
            var list = s.data!;
            if (filter == FilterType.badge) {
              final rank = {
                BadgeLevel.gold: 4,
                BadgeLevel.silver: 3,
                BadgeLevel.bronze: 2,
                BadgeLevel.none: 1,
              };
              list.sort((a, b) => rank[b.level]!.compareTo(rank[a.level]!));
            }
            var filtered = list.where((e) {
              switch (filter) {
                case FilterType.verified:
                  return e.verified;
                case FilterType.topRated:
                  return e.rating >= 4.5;
                case FilterType.highReferral:
                  return e.referrals >= 10;
                case FilterType.clean:
                  return e.penalty < 20;
                case FilterType.badge:
                case FilterType.all:
                  return true;
              }
            }).toList();

            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No fundis for this filter',
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              );
            }
            return Column(
              children: filtered
                  .map(
                    (e) => PendingBidCard(bid: e, jobId: jobId, jobData: job),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}
