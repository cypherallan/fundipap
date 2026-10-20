import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/job_taxonomy.dart';
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '24 CATEGORIES TAXONOMY - SYSTEM PRICING',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            'Rule: Client & Fundi NEVER dictate price. Site visit KES ${FundiTaxonomy.siteVisitFeeStandard} mandatory.',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                icon: seeding
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.cloud_upload, color: Colors.white),
                label: Text(
                  seeding ? 'Seeding...' : 'SEED 24 CATEGORIES + PRICING',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                ),
                onPressed: seeding
                    ? null
                    : () async {
                        setState(() {
                          seeding = true;
                          log = 'Seeding...';
                        });
                        try {
                          var res = await TaxonomyService.seedAll();
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
                icon: Icon(Icons.delete_forever, size: 18),
                label: Text('CLEAR ALL'),
                onPressed: () => TaxonomyService.clearAll(context),
              ),
            ],
          ),
          if (log.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 12),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(log, style: GoogleFonts.inter(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
