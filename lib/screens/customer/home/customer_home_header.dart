import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class CustomerHomeHeader extends StatelessWidget {
  final Map<String, dynamic>? me;
  final int profilePct;
  final int completedJobs;
  final VoidCallback onProfileTap;
  const CustomerHomeHeader({
    super.key,
    this.me,
    this.profilePct = 0,
    this.completedJobs = 0,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    double avg = ((me?['clientRatingAvg'] ?? me?['rating'] ?? 0) as num)
        .toDouble();
    int count = (me?['clientRatingCount'] ?? 0) as int;

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: FundipapColors.primaryYellow,
          child: Text(
            (me?['name'] ?? 'C')[0],
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                me?['name'] ?? 'Customer',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              Text(
                '$completedJobs jobs done • $profilePct% profile',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
              ),
              if (count > 0)
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${avg.toStringAsFixed(1)} ($count ${count == 1 ? 'review' : 'reviews'})',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'No ratings yet',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onProfileTap,
          icon: const Icon(Icons.person, color: Colors.white),
        ),
      ],
    );
  }
}
