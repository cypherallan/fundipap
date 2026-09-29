import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/fundi_badge_chip.dart';
import '../models/customer_home_models.dart';
import '../helpers/customer_home_utils.dart';
import '../../post_new_job_screen.dart';
import '../../confirm/confirm_fundi_page.dart';
import '../../../../services/fundi_badge_service.dart';

class CustomerPendingSection extends StatelessWidget {
  final String uid;
  final FilterType pendingFilter;
  final ValueChanged<FilterType> onFilterChanged;
  final Position? userPos;

  const CustomerPendingSection({
    super.key,
    required this.uid,
    required this.pendingFilter,
    required this.onFilterChanged,
    required this.userPos,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('customerId', isEqualTo: uid)
          .where('status', whereIn: ['open', 'pending'])
          .snapshots(),
      builder: (context, snap1) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .where('clientId', isEqualTo: uid)
              .where('status', whereIn: ['open', 'pending'])
              .snapshots(),
          builder: (context, snap2) {
            if (snap1.connectionState == ConnectionState.waiting ||
                snap2.connectionState == ConnectionState.waiting) {
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(20),
                child: const LinearProgressIndicator(),
              );
            }
            final Map<String, QueryDocumentSnapshot> map = {};
            if (snap1.hasData) for (var d in snap1.data!.docs) map[d.id] = d;
            if (snap2.hasData) for (var d in snap2.data!.docs) map[d.id] = d;
            var jobs = map.values.toList();

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FundipapColors.blackGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.work_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pending Jobs',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FundipapColors.primaryYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${jobs.length}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<FilterType>(
                        value: pendingFilter,
                        isExpanded: true,
                        icon: const Icon(Icons.filter_list, size: 18),
                        items: [
                          DropdownMenuItem(
                            value: FilterType.all,
                            child: Text(
                              'Filter By',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.verified,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Verified',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.topRated,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Top Rated 4.5+',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.highReferral,
                            child: Row(
                              children: [
                                const Icon(Icons.people, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'High Referral 10+',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.clean,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.clean_hands,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Clean Record',
                                  style: GoogleFonts.montserrat(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: FilterType.badge,
                            child: Row(
                              children: [
                                Text(
                                  'Badge Ranking',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const FundiBadgeChip(level: BadgeLevel.gold),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) => onFilterChanged(v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PostNewJobScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.black),
                      label: Text(
                        'Post New Job',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (jobs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.work_outline,
                              size: 28,
                              color: Colors.black26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pending jobs',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap Post New Job above to get bids',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...jobs.map((jobDoc) {
                      var job = jobDoc.data() as Map<String, dynamic>;
                      var jobId = jobDoc.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.fromLTRB(
                              12,
                              10,
                              12,
                              10,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              12,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: FundipapColors.blackGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  (job['title'] ?? 'J')[0].toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              job['title'] ?? 'Untitled Job',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FundipapColors.primaryYellow
                                          .withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'KES ${job['budgetMin'] ?? job['budget'] ?? '-'} - ${job['budgetMax'] ?? ''}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('jobs')
                                        .doc(jobId)
                                        .collection('bids')
                                        .snapshots(),
                                    builder: (_, s) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${s.data?.docs.length ?? 0} bids',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  child: Text(
                                    'Delete',
                                    style: GoogleFonts.inter(),
                                  ),
                                  onTap: () => deleteJob(jobId),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                            children: [
                              const Divider(height: 1),
                              const SizedBox(height: 10),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('jobs')
                                    .doc(jobId)
                                    .collection('bids')
                                    .snapshots(),
                                builder: (_, bSnap) {
                                  if (!bSnap.hasData)
                                    return const LinearProgressIndicator();
                                  if (bSnap.data!.docs.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.hourglass_empty,
                                            color: Colors.black26,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Waiting for fundis to bid',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return FutureBuilder<List<BidWithFundi>>(
                                    future: enrichBids(
                                      bSnap.data!.docs,
                                      userPos,
                                    ),
                                    builder: (_, s) {
                                      if (!s.hasData)
                                        return const LinearProgressIndicator();
                                      var list = s.data!;
                                      if (pendingFilter == FilterType.badge) {
                                        final rank = {
                                          BadgeLevel.gold: 4,
                                          BadgeLevel.silver: 3,
                                          BadgeLevel.bronze: 2,
                                          BadgeLevel.none: 1,
                                        };
                                        list.sort(
                                          (a, b) => rank[b.level]!.compareTo(
                                            rank[a.level]!,
                                          ),
                                        );
                                      }
                                      var filtered = list.where((e) {
                                        switch (pendingFilter) {
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
                                      if (filtered.isEmpty)
                                        return Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'No fundis for this filter',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      return Column(
                                        children: filtered.map((e) {
                                          void openConfirm() {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ConfirmFundiPage(
                                                      jobId: jobId,
                                                      jobData: job,
                                                      bidId: e.bidDoc.id,
                                                      bidData: e.bid,
                                                    ),
                                              ),
                                            );
                                          }

                                          String distanceText = e.distanceKm > 0
                                              ? ' (${e.distanceKm.toStringAsFixed(1)} km)'
                                              : '';
                                          return InkWell(
                                            onTap: openConfirm,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8F8F8),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: Colors.black12,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor:
                                                            Colors.black,
                                                        child: Text(
                                                          (e.bid['fundiName'] ??
                                                              'F')[0],
                                                          style:
                                                              GoogleFonts.montserrat(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    '${e.bid['fundiName'] ?? 'Fundi'}$distanceText',
                                                                    style: GoogleFonts.montserrat(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                if (e.verified)
                                                                  const Padding(
                                                                    padding:
                                                                        EdgeInsets.only(
                                                                          left:
                                                                              4,
                                                                        ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .verified,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .blue,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.star,
                                                                  size: 12,
                                                                  color: Colors
                                                                      .amber
                                                                      .shade700,
                                                                ),
                                                                Text(
                                                                  '${e.rating.toStringAsFixed(1)}',
                                                                  style: GoogleFonts.inter(
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Text(
                                                                  '${e.referrals} referrals • ${e.jobsDone} jobs',
                                                                  style: GoogleFonts.inter(
                                                                    fontSize:
                                                                        10,
                                                                    color: Colors
                                                                        .black54,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      FundiBadgeChip(
                                                        level: e.level,
                                                        isVerified: e.verified,
                                                        referralCount:
                                                            e.referrals,
                                                        jobsDone: e.jobsDone,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Bid',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .black54,
                                                            ),
                                                      ),
                                                      Text(
                                                        'KES ${e.bid['price'] ?? e.bid['amount'] ?? e.bid['bidAmount'] ?? 0}',
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800,
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton(
                                                          style: OutlinedButton.styleFrom(
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            side:
                                                                const BorderSide(
                                                                  color: Colors
                                                                      .black12,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'Counter',
                                                            style:
                                                                GoogleFonts.montserrat(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                          ),
                                                          onPressed:
                                                              openConfirm,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                FundipapColors
                                                                    .blackGray,
                                                            foregroundColor:
                                                                Colors.white,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                            elevation: 0,
                                                          ),
                                                          child: Text(
                                                            'View & Accept',
                                                            style:
                                                                GoogleFonts.montserrat(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                ),
                                                          ),
                                                          onPressed:
                                                              openConfirm,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
