import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FundiJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMatch;
  final VoidCallback onBid;
  final VoidCallback onTap;
  final double? distanceKm;

  const FundiJobCard({
    super.key,
    required this.data,
    required this.isMatch,
    required this.onBid,
    required this.onTap,
    this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final clientName =
        data['customerUsername'] ??
        data['customerName'] ??
        data['clientName'] ??
        'Client';
    // Fundi sees ONLY what client offered, not range
    final offered =
        data['budget'] ?? data['offeredPrice'] ?? data['amount'] ?? 0;
    final budgetText = 'KES $offered';
    final distanceText = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)}km away'
        : (data['distance'] ?? 'Kisumu');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMatch ? Colors.white : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: isMatch
              ? Border.all(color: FundipapColors.primaryYellow, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: FundipapColors.blackGray,
                  child: Text(
                    clientName[0].toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clientName,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        distanceText,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                    (data['category'] ?? 'General').toString().toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
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
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  budgetText,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['title'] ?? 'Job',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data['location'] ?? 'Kisumu',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
