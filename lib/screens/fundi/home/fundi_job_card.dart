import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMatch;
  final VoidCallback? onBid; // <-- changed to nullable so we can disable
  final VoidCallback onTap;
  final double? distanceKm;
  final bool hasBid; // <-- ADDED

  const FundiJobCard({
    super.key,
    required this.data,
    required this.isMatch,
    required this.onBid,
    required this.onTap,
    this.distanceKm,
    this.hasBid = false, // <-- default false
  });

  @override
  Widget build(BuildContext context) {
    final clientName =
        data['customerUsername'] ??
        data['customerName'] ??
        data['clientName'] ??
        'Client';
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
          color: hasBid
              ? const Color(0xFFF0FFF0)
              : isMatch
              ? Colors.white
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: hasBid
              ? Border.all(color: FundipapColors.greenSuccess, width: 1.5)
              : isMatch
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
                if (hasBid) ...[
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
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 10, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          'BID PLACED',
                          style: GoogleFonts.montserrat(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
            const SizedBox(height: 10),
            // BID BUTTON OR WAITING MESSAGE
            if (hasBid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: FundipapColors.greenSuccess.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: FundipapColors.greenSuccess.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.hourglass_top,
                      size: 14,
                      color: FundipapColors.greenSuccess,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You have placed a bid on this job. Wait for client feedback',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FundipapColors.greenSuccess,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FundipapColors.blackGray,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onBid,
                  child: Text(
                    'Place Bid',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
