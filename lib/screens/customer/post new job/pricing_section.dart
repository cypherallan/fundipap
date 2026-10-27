import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/dynamic_pricing_service.dart';
import '../../../services/pricing_service.dart';

class PricingSection extends StatelessWidget {
  final String categoryId;
  final String subcategoryId;
  final String? faultId;
  final Map<String, dynamic> selectedCategory;
  final Map<String, dynamic>? selectedSub;

  const PricingSection({
    super.key,
    required this.categoryId,
    required this.subcategoryId,
    required this.faultId,
    required this.selectedCategory,
    required this.selectedSub,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: DynamicPricingService.statsStream(
        categoryId,
        subcategoryId,
        faultId: faultId,
      ),
      builder: (context, snap) {
        final stats = snap.data?.data() as Map<String, dynamic>?;
        final hasMarket = stats != null && (stats['count'] ?? 0) >= 5;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasMarket ? Colors.green.shade50 : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasMarket ? Colors.green.shade300 : Colors.amber.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasMarket ? Icons.analytics : Icons.lightbulb_outline,
                    size: 18,
                    color: hasMarket ? Colors.green.shade800 : Colors.black87,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      hasMarket
                          ? 'Market Average (Fundi Bids)'
                          : 'System Estimate (Fundis will set real price)',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (stats == null)
                Text(
                  'No history yet for ${selectedCategory['name']} > ${selectedSub?['name'] ?? ''}. You will be first - fundis will bid and system will learn.',
                  style: GoogleFonts.inter(fontSize: 11),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DynamicPricingService.formatRange(stats),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${stats['count']} fundi bids • Min ${stats['min']} • Max ${stats['max']} • Avg ${stats['avg']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    if ((stats['count'] ?? 0) < 5)
                      Text(
                        'Still learning - need ${5 - (stats['count'] as int)} more bids. Showing system estimate for now.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.orange.shade800,
                        ),
                      ),
                  ],
                ),
              if (stats == null)
                FutureBuilder<Map<String, dynamic>>(
                  future: PricingService.getPriceToShow(
                    categoryId: categoryId,
                    subcategoryId: subcategoryId,
                    faultId: faultId,
                  ),
                  builder: (_, priceSnap) {
                    if (!priceSnap.hasData) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        priceSnap.data!['rangeText'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.handshake_outlined,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Fundi sets price when bidding. You negotiate until mutual price. Extra labor only after site visit + your approval.',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
