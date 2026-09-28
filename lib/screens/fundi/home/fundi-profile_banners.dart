import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/fundi_badge_chip.dart';
import '../../../services/fundi_badge_service.dart';

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
                  'You are at $profilePct% - clients prefer 100% for Gold badge',
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

class FundiBadgeProgressBanner extends StatelessWidget {
  final BadgeResult badge;
  final int completedJobs; // <-- ADDED
  const FundiBadgeProgressBanner({
    super.key,
    required this.badge,
    this.completedJobs = 0,
  });

  @override
  Widget build(BuildContext context) {
    int referrals = (badge.breakdown['referrals'] ?? 0) ~/ 2;
    String next = badge.level == BadgeLevel.none
        ? 'Bronze (${FundiBadgeService.bronzeMin}pts)'
        : badge.level == BadgeLevel.bronze
        ? 'Silver (${FundiBadgeService.silverMin}pts)'
        : badge.level == BadgeLevel.silver
        ? 'Gold (${FundiBadgeService.goldMin}pts)'
        : 'VERIFIED';
    int need = badge.level == BadgeLevel.none
        ? FundiBadgeService.bronzeMin - badge.score
        : badge.level == BadgeLevel.bronze
        ? FundiBadgeService.silverMin - badge.score
        : badge.level == BadgeLevel.silver
        ? FundiBadgeService.goldMin - badge.score
        : 0;
    if (need < 0) need = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Badge',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              FundiBadgeChip(
                level: badge.level,
                isVerified: badge.isVerified,
                referralCount: referrals,
                jobsDone: completedJobs,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (badge.score / FundiBadgeService.goldMin)
                .clamp(0, 1)
                .toDouble(),
            backgroundColor: Colors.black12,
            color: FundipapColors.blackGray,
          ),
          const SizedBox(height: 6),
          Text(
            badge.level == BadgeLevel.gold && badge.isVerified
                ? 'You are VERIFIED ✔ - you appear first to clients'
                : 'Score ${badge.score}pts - $need more to reach $next',
            style: GoogleFonts.inter(fontSize: 10),
          ),
          if ((badge.breakdown['cancellations'] ?? 0) < 0)
            Text(
              '⚠ Cancellations hurting your score: ${badge.breakdown['cancellations']}pts',
              style: GoogleFonts.inter(fontSize: 9, color: Colors.red),
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
