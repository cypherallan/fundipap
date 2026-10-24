import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/fundi_badge_chip.dart';
import '../services/fundi_badge_service.dart';

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
  final int completedJobs;
  const FundiBadgeProgressBanner({
    super.key,
    required this.badge,
    this.completedJobs = 0,
  });

  @override
  Widget build(BuildContext context) {
    int referrals = badge.referralRate > 0
        ? (badge.referralRate * completedJobs).round()
        : (badge.breakdown['referral'] ?? 0);

    String nextBadge;
    if (badge.badgeLevel == BadgeLevel.none) {
      nextBadge = 'Bronze (35pts) 15%→10%';
    } else if (badge.badgeLevel == BadgeLevel.bronze)
      nextBadge = 'Silver (70pts) 10%→8%';
    else if (badge.badgeLevel == BadgeLevel.silver)
      nextBadge = 'Gold (110pts) 8%→5%';
    else
      nextBadge = 'MAX 5%';

    String nextLevel;
    if (badge.fundiLevel == FundiLevel.L1_NEW) {
      nextLevel = 'L2 HUSTLER (10 jobs)';
    } else if (badge.fundiLevel == FundiLevel.L2_HUSTLER)
      nextLevel = 'L3 PRO (50 jobs)';
    else if (badge.fundiLevel == FundiLevel.L3_PRO)
      nextLevel = 'L4 ELITE (100 jobs)';
    else
      nextLevel = 'ELITE MAX';

    double progress = badge.isTrialGold
        ? (completedJobs / 10).clamp(0, 1).toDouble()
        : (badge.score / 130).clamp(0, 1).toDouble();

    Color progressColor = badge.isTrialGold
        ? const Color(0xFFFFD700)
        : badge.badgeLevel == BadgeLevel.gold
        ? const Color(0xFFFFD700)
        : badge.badgeLevel == BadgeLevel.silver
        ? Colors.grey.shade400
        : badge.badgeLevel == BadgeLevel.bronze
        ? const Color(0xFFCD7F32)
        : Colors.red;

    int daysLeft = 0;
    if (badge.isTrialGold && badge.trialExpiresAt != null) {
      daysLeft = badge.trialExpiresAt!
          .difference(DateTime.now())
          .inDays
          .clamp(0, 14);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Level & Badge',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              FundiBadgeChip(
                level: badge.badgeLevel,
                fundiLevel: badge.fundiLevel,
                isVerified: badge.isVerified,
                isTrialGold: badge.isTrialGold,
                trialExpiresAt: badge.trialExpiresAt,
                referralCount: referrals,
                jobsDone: completedJobs,
                commissionPct: badge.fundiCommissionPct,
                compact: false,
                showLevel: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.isVerified
                ? 'VERIFIED ✔ ${badge.score}/130 pts - You appear first, ${badge.fundiCommissionPct}% fee'
                : badge.isTrialGold
                ? 'GOLD TRIAL - $completedJobs/10 jobs - $daysLeft days left - Finish profile+KYC or drop to NEW 15%'
                : 'Score ${badge.score}/130 pts - ${badge.pointsToNextBadge} pts to $nextBadge - ${badge.jobsToNextLevel} jobs to $nextLevel - Fee: ${badge.fundiCommissionPct}%',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          if ((badge.breakdown['cancellations'] ?? 10) < 10)
            Text(
              '⚠ Avoid cancellations: ${badge.breakdown['cancellations']}pts',
              style: GoogleFonts.inter(fontSize: 9, color: Colors.red),
            ),
          if ((badge.breakdown['profileComplete'] ?? 0) == 0)
            Text(
              '⚠ Complete My Advert tab: ID + Good Conduct + Trade Cert + Photo + Bio = 10pts',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.orange.shade800,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            'Referral rate: ${(badge.referralRate * 100).toStringAsFixed(0)}% - Ask clients to refer you',
            style: GoogleFonts.inter(fontSize: 9, color: Colors.black54),
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
