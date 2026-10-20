import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../services/taxonomy_service.dart';

class TaxonomySeedCard extends StatefulWidget {
  const TaxonomySeedCard({super.key});
  @override
  State<TaxonomySeedCard> createState() => _TaxonomySeedCardState();
}

class _TaxonomySeedCardState extends State<TaxonomySeedCard> {
  bool seeding = false;
  String log = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FundipapColors.blackGray,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.category,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '24 CATEGORIES - MARKET PRICING',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Business Rule:',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Client & Fundi agree price via Bid / Counter\n• Client locks: Agreed Labour + 5% platform fee\n• Fundi receives: Agreed Labour - Badge % (Bronze 10%, Silver 7%, Gold 5%)\n• NO mandatory site visit fee. Site visit is part of negotiation.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: seeding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.cloud_upload,
                        color: Colors.white,
                        size: 18,
                      ),
                label: Text(
                  seeding ? 'Seeding...' : 'SEED 24 CATEGORIES ONLY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: seeding
                    ? null
                    : () async {
                        setState(() {
                          seeding = true;
                          log = 'Seeding 24 categories (no prices)...';
                        });
                        try {
                          // This now seeds ONLY id, name, slug, subcategories - NO priceMin/max, NO siteVisitFee
                          var res = await TaxonomyService.seedCategoriesOnly();
                          setState(() {
                            log = res;
                            seeding = false;
                          });
                        } catch (e) {
                          setState(() {
                            log = '❌ $e';
                            seeding = false;
                          });
                        }
                      },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('CLEAR ALL', style: TextStyle(fontSize: 11)),
                onPressed: () => TaxonomyService.clearAll(context),
              ),
            ],
          ),
          if (log.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(log, style: GoogleFonts.inter(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
