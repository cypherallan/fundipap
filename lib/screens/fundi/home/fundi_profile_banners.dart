import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiProfileIncompleteBanner extends StatelessWidget {
  final int profilePct;
  const FundiProfileIncompleteBanner({super.key, required this.profilePct});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FundipapColors.primaryYellow.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$profilePct%',
            style: GoogleFonts.montserrat(
              color: FundipapColors.primaryYellow,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your profile to get noticed',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  'You are at $profilePct% - clients prefer 100%',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FundiProfileCompleteBanner extends StatelessWidget {
  const FundiProfileCompleteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FundipapColors.greenSuccess.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FundipapColors.greenSuccess),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: FundipapColors.greenSuccess,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '100% Complete - you rank higher!',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class FundiBioCard extends StatelessWidget {
  final String bio;
  const FundiBioCard({super.key, required this.bio});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        bio,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}
