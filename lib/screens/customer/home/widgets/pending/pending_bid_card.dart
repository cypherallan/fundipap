import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/fundi_badge_chip.dart';
import '../../models/customer_home_models.dart';
import '../../../confirm/confirm_fundi_page.dart';

class PendingBidCard extends StatelessWidget {
  final BidWithFundi bid;
  final String jobId;
  final Map<String, dynamic> jobData;

  const PendingBidCard({
    super.key,
    required this.bid,
    required this.jobId,
    required this.jobData,
  });

  @override
  Widget build(BuildContext context) {
    void openConfirm() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmFundiPage(
            jobId: jobId,
            jobData: jobData,
            bidId: bid.bidDoc.id,
            bidData: bid.bid,
          ),
        ),
      );
    }

    String distanceText = bid.distanceKm > 0
        ? ' (${bid.distanceKm.toStringAsFixed(1)} km)'
        : '';

    return InkWell(
      onTap: openConfirm,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black,
                  child: Text(
                    (bid.bid['fundiName'] ?? 'F')[0],
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${bid.bid['fundiName'] ?? 'Fundi'}$distanceText',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (bid.verified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber.shade700,
                          ),
                          Text(
                            '${bid.rating.toStringAsFixed(1)}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${bid.referrals} referrals • ${bid.jobsDone} jobs',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FundiBadgeChip(
                  level: bid.level,
                  isVerified: bid.verified,
                  referralCount: bid.referrals,
                  jobsDone: bid.jobsDone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bid',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  'KES ${bid.bid['price'] ?? bid.bid['amount'] ?? bid.bid['bidAmount'] ?? 0}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    child: Text(
                      'Counter',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: openConfirm,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.blackGray,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'View & Accept',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: openConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
