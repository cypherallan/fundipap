import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/fundi_badge_chip.dart';
import '../../../services/fundi_badge_service.dart';

enum FilterType { all, verified, topRated, highReferral, clean, badge }

class _BidWithFundi {
  final QueryDocumentSnapshot bidDoc;
  final Map<String, dynamic> bid;
  final BadgeLevel level;
  final bool verified;
  final int referrals;
  final int jobsDone;
  final double rating;
  final int penalty;
  _BidWithFundi({
    required this.bidDoc,
    required this.bid,
    required this.level,
    required this.verified,
    required this.referrals,
    required this.jobsDone,
    required this.rating,
    required this.penalty,
  });
}

class ClientPendingTab extends StatefulWidget {
  final List<QueryDocumentSnapshot> jobs;
  final Future<void> Function(BuildContext, DocumentReference, String, double)
  onCounter;
  final Future<void> Function(
    BuildContext,
    DocumentReference,
    String,
    Map<String, dynamic>,
  )
  onAccept;
  final Future<void> Function(BuildContext, String, Map<String, dynamic>)
  onEdit;
  final Future<void> Function(BuildContext, String) onDelete;
  const ClientPendingTab({
    super.key,
    required this.jobs,
    required this.onCounter,
    required this.onAccept,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ClientPendingTab> createState() => _ClientPendingTabState();
}

class _ClientPendingTabState extends State<ClientPendingTab> {
  FilterType _filter = FilterType.all;

  BadgeLevel _parse(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'gold':
        return BadgeLevel.gold;
      case 'silver':
        return BadgeLevel.silver;
      case 'bronze':
        return BadgeLevel.bronze;
      default:
        return BadgeLevel.none;
    }
  }

  Future<List<_BidWithFundi>> _enrich(List<QueryDocumentSnapshot> bids) async {
    return Future.wait(
      bids.map((b) async {
        var m = b.data() as Map<String, dynamic>;
        var fid = (m['fundiId'] ?? m['uid'] ?? '').toString();
        Map<String, dynamic>? f;
        if (fid.isNotEmpty) {
          var d = await FirebaseFirestore.instance
              .collection('users')
              .doc(fid)
              .get();
          f = d.data();
        }
        return _BidWithFundi(
          bidDoc: b,
          bid: m,
          level: _parse(f?['badgeLevel']),
          verified: f?['isVerifiedFundi'] == true,
          referrals: f?['referralCount'] ?? 0,
          jobsDone: f?['completedJobs'] ?? 0,
          rating: (f?['avgRating'] ?? 0).toDouble(),
          penalty: f?['penaltyScore'] ?? 0,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobs.isEmpty) {
      return Center(child: Text('No pending jobs', style: GoogleFonts.inter()));
    }

    return Column(
      children: [
        // ONE FILTER DROPDOWN - Badge is one option inside it
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FilterType>(
                value: _filter,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: FilterType.all,
                    child: Text(
                      'All Fundis',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: FilterType.verified,
                    child: Text(
                      'Verified',
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                  ),
                  DropdownMenuItem(
                    value: FilterType.topRated,
                    child: Text(
                      'Top Rated',
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                  ),
                  DropdownMenuItem(
                    value: FilterType.highReferral,
                    child: Text(
                      'High Referral',
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                  ),
                  DropdownMenuItem(
                    value: FilterType.clean,
                    child: Text(
                      'Clean Record',
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                  ),
                  DropdownMenuItem(
                    value: FilterType.badge,
                    child: Row(
                      children: [
                        Text(
                          'Badge',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const FundiBadgeChip(
                          level: BadgeLevel.gold,
                        ), // generic, no fake numbers
                      ],
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: widget.jobs.length,
            itemBuilder: (_, i) {
              var jobDoc = widget.jobs[i];
              var job = jobDoc.data() as Map<String, dynamic>;
              var jobId = jobDoc.id;

              // JOB AS DROPDOWN
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  title: Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'KES ${job['budget']} • ${job['status']}',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('jobs')
                          .doc(jobId)
                          .collection('bids')
                          .snapshots(),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return const LinearProgressIndicator();
                        }
                        var bids = snap.data!.docs;
                        if (bids.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No bids yet'),
                          );
                        }

                        return FutureBuilder<List<_BidWithFundi>>(
                          future: _enrich(bids),
                          builder: (_, s) {
                            if (!s.hasData) {
                              return const LinearProgressIndicator();
                            }
                            var list = s.data!;

                            // If Badge filter is selected -> show fundis by badge, Gold first, Grey last, skip missing
                            if (_filter == FilterType.badge) {
                              final rank = {
                                BadgeLevel.gold: 4,
                                BadgeLevel.silver: 3,
                                BadgeLevel.bronze: 2,
                                BadgeLevel.none: 1,
                              };
                              list.sort(
                                (a, b) =>
                                    rank[b.level]!.compareTo(rank[a.level]!),
                              );
                              // list already skips missing because we only sort what exists
                            }

                            // Apply other filters
                            var filtered = list.where((e) {
                              switch (_filter) {
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
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('No fundis for this filter'),
                              );
                            }

                            return Column(
                              children: filtered
                                  .map(
                                    (e) => Container(
                                      margin: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        8,
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF6F6F6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${e.bid['fundiName'] ?? 'Fundi'} • KES ${e.bid['price']}',
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              FundiBadgeChip(
                                                level: e.level,
                                                isVerified: e.verified,
                                                referralCount: e.referrals,
                                                jobsDone: e.jobsDone,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      widget.onCounter(
                                                        context,
                                                        e.bidDoc.reference,
                                                        jobId,
                                                        (e.bid['price'])
                                                            .toDouble(),
                                                      ),
                                                  child: const Text('Counter'),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            FundipapColors
                                                                .greenSuccess,
                                                      ),
                                                  onPressed: () =>
                                                      widget.onAccept(
                                                        context,
                                                        e.bidDoc.reference,
                                                        jobId,
                                                        e.bid,
                                                      ),
                                                  child: const Text(
                                                    'Accept',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
