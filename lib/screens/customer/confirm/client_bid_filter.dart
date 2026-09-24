import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../services/dynamic_pricing_service.dart';

/// CLIENT BID LIST WITH FILTERING - Price, Rating, Jobs Done, Distance, Zero Fraud
/// Shows average range for that service

class ClientBidFilterBar extends StatelessWidget {
  final String selectedSort;
  final bool ascending;
  final Function(String sortBy, bool ascending) onSortChanged;
  const ClientBidFilterBar({
    super.key,
    required this.selectedSort,
    required this.ascending,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = [
      {'id': 'price', 'label': 'Price', 'icon': Icons.payments_outlined},
      {'id': 'rating', 'label': 'Rating', 'icon': Icons.star_outline},
      {'id': 'jobsDone', 'label': 'Jobs Done', 'icon': Icons.work_outline},
      {
        'id': 'distance',
        'label': 'Distance',
        'icon': Icons.location_on_outlined,
      },
      {
        'id': 'fraud',
        'label': 'Zero Scam',
        'icon': Icons.verified_user_outlined,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          bool isSelected = selectedSort == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    f['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(
                      ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              selectedColor: FundipapColors.blackGray,
              backgroundColor: Colors.grey.shade100,
              checkmarkColor: Colors.white,
              onSelected: (_) {
                if (isSelected) {
                  onSortChanged(f['id'] as String, !ascending);
                } else {
                  bool asc =
                      f['id'] == 'price' ||
                      f['id'] == 'distance' ||
                      f['id'] == 'fraud';
                  onSortChanged(f['id'] as String, asc);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Full Bid List Widget for Confirm Fundi Page
class ClientBidsListWithFilter extends StatefulWidget {
  final String jobId;
  final String categoryId;
  final String subcategoryId;
  final String? faultId;
  const ClientBidsListWithFilter({
    super.key,
    required this.jobId,
    required this.categoryId,
    required this.subcategoryId,
    this.faultId,
  });

  @override
  State<ClientBidsListWithFilter> createState() =>
      _ClientBidsListWithFilterState();
}

class _ClientBidsListWithFilterState extends State<ClientBidsListWithFilter> {
  String sortBy = 'price';
  bool ascending = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Market average header
        StreamBuilder<DocumentSnapshot>(
          stream: DynamicPricingService.statsStream(
            widget.categoryId,
            widget.subcategoryId,
            faultId: widget.faultId,
          ),
          builder: (_, snap) {
            var data = snap.data?.data() as Map<String, dynamic>?;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data == null
                          ? 'No market history yet - you will set the first average'
                          : DynamicPricingService.formatRange(data),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Filter Bids',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ClientBidFilterBar(
          selectedSort: sortBy,
          ascending: ascending,
          onSortChanged: (s, asc) => setState(() {
            sortBy = s;
            ascending = asc;
          }),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.jobId)
              .collection('bids')
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var bids = snap.data!.docs
                .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                .toList();
            if (bids.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No bids yet - fundis will bid with their price',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
                ),
              );
            }

            var sorted = DynamicPricingService.sortBids(
              bids: bids,
              sortBy: sortBy,
              ascending: ascending,
            );

            return Column(
              children: sorted.map((bid) {
                int price = (bid['amount'] ?? 0).toInt();
                double rating = (bid['fundiRating'] ?? 0).toDouble();
                int jobsDone = (bid['fundiJobsCompleted'] ?? 0).toInt();
                int fraud = (bid['fraudCount'] ?? 0).toInt();
                double distance = (bid['distanceKm'] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: bid['fundiPhoto'] != null
                          ? NetworkImage(bid['fundiPhoto'])
                          : null,
                      child: bid['fundiPhoto'] == null
                          ? Text((bid['fundiName'] ?? 'F')[0])
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(
                          bid['fundiName'] ?? 'Fundi',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (fraud == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Zero scam ✓',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.payments,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'KES $price',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber.shade700,
                            ),
                            Text(
                              ' $rating',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.work, size: 14),
                            Text(
                              ' $jobsDone jobs',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                          ],
                        ),
                        if (distance > 0)
                          Text(
                            '${distance.toStringAsFixed(1)} km away • ${bid['note'] ?? ''}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.blackGray,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        // Accept bid -> renegotiation can start
                        // Your existing confirm_fundi logic here
                      },
                      child: Text(
                        'View',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
