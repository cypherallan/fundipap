import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FundiJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMatch;
  final VoidCallback onBid;

  const FundiJobCard({
    super.key,
    required this.data,
    required this.isMatch,
    required this.onBid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMatch
            ? Colors.white
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: isMatch
            ? Border.all(
                color: FundipapColors.primaryYellow,
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isMatch
                      ? FundipapColors.primaryYellow
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (data['category'] ?? 'General')
                      .toString()
                      .toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isMatch) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: FundipapColors.greenSuccess,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'FOR YOU',
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'KES ${data['budget'] ?? 1500}',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data['title'] ?? 'Job',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['description'] ?? '',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.place,
                size: 12,
                color: Colors.black45,
              ),
              Text(
                ' ${data['location'] ?? 'Kisumu'} • ${data['distance'] ?? '1.2km'}',
                style: GoogleFonts.inter(fontSize: 10),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onBid,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                  ),
                ),
                child: Text(
                  'BID',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}