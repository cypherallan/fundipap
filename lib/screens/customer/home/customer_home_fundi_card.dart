import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class CustomerHomeFundiCard extends StatelessWidget {
  final Map<String, dynamic> fundi;
  final VoidCallback onHire;
  const CustomerHomeFundiCard({
    super.key,
    required this.fundi,
    required this.onHire,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: FundipapColors.primaryYellow,
            child: Text(
              (fundi['name'] ?? 'F')[0],
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fundi['name'] ?? 'Fundi',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (fundi['verified'] == true)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.verified,
                          size: 14,
                          color: FundipapColors.greenSuccess,
                        ),
                      ),
                  ],
                ),
                Text(
                  "${fundi['skill'] ?? 'General'} • ${fundi['jobs'] ?? 0} jobs",
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    Text(
                      " ${fundi['rating'] ?? 4.5}",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.place, size: 14, color: Colors.black45),
                    Text(
                      " ${(fundi['calcDistance'] as double).toStringAsFixed(1)} km",
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "KES ${fundi['price'] ?? 0}",
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onHire,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Hire',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
