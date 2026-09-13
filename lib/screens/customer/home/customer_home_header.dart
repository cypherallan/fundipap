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
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: FundipapColors.primaryYellow,
          child: Text(
            (me?['name'] ?? 'C')[0],
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
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
