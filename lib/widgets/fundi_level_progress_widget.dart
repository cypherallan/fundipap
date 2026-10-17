import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/fundi_badge_service.dart';
import 'fundi_badge_chip.dart';

class FundiLevelProgressWidget extends StatelessWidget {
  final BadgeResult badge;
  final int completedJobs;
  const FundiLevelProgressWidget({
    super.key,
    required this.badge,
    required this.completedJobs,
  });

  @override
  Widget build(BuildContext context) {
    double levelProgress;
    String levelNextText;

    if (badge.isTrialGold) {
      levelProgress = (completedJobs / 10).clamp(0, 1).toDouble();
      int left = 10 - completedJobs;
      levelNextText =
          '$left jobs left in trial - finish KYC + video + tools or drop to NEW 15%';
      if (left <= 0) {
        levelNextText = 'Trial ending - complete profile to avoid NEW 15%';
      }
    } else if (badge.fundiLevel == FundiLevel.L1_NEW) {
      levelProgress = (completedJobs / 10).clamp(0, 1).toDouble();
      levelNextText = '${10 - completedJobs} jobs to L2 HUSTLER';
      if (levelNextText.contains('-')) levelNextText = 'Ready for L2 HUSTLER';
    } else if (badge.fundiLevel == FundiLevel.L2_HUSTLER) {
      levelProgress = ((completedJobs - 10) / 40).clamp(0, 1).toDouble();
      levelNextText = '${50 - completedJobs} jobs to L3 PRO (unlimited bids)';
    } else if (badge.fundiLevel == FundiLevel.L3_PRO) {
      levelProgress = ((completedJobs - 50) / 50).clamp(0, 1).toDouble();
      levelNextText = '${100 - completedJobs} jobs to L4 ELITE (top priority)';
    } else {
      levelProgress = 1.0;
      levelNextText = 'ELITE MAX - You get first priority';
    }

    double badgeProgress = badge.isTrialGold
        ? (completedJobs / 10).clamp(0, 1).toDouble()
        : (badge.score / 130).clamp(0, 1).toDouble();
    String badgeNextText;
    if (badge.isTrialGold) {
      badgeNextText =
          '$completedJobs/10 jobs done - Need ${10 - completedJobs} more to reach L2, keep profile complete to avoid NEW 15%';
    } else if (badge.badgeLevel == BadgeLevel.none) {
      badgeNextText = '${badge.pointsToNextBadge} pts to BRONZE (15% → 10%)';
    } else if (badge.badgeLevel == BadgeLevel.bronze) {
      badgeNextText = '${badge.pointsToNextBadge} pts to SILVER (10% → 8%)';
    } else if (badge.badgeLevel == BadgeLevel.silver) {
      badgeNextText = '${badge.pointsToNextBadge} pts to GOLD (8% → 5%)';
    } else {
      badgeNextText = 'GOLD MAX - 5% fee locked';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Growth Path',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              FundiBadgeChip(
                level: badge.badgeLevel,
                fundiLevel: badge.fundiLevel,
                isVerified: badge.isVerified,
                isTrialGold: badge.isTrialGold,
                trialExpiresAt: badge.trialExpiresAt,
                commissionPct: badge.fundiCommissionPct,
                jobsDone: completedJobs,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'LEVEL: ${badge.fundiLevel.name} ($completedJobs jobs)',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 10,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(FundipapColors.blackGray),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            levelNextText,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            badge.isTrialGold
                ? 'TRIAL PROGRESS: $completedJobs/10 jobs - Fee ${badge.fundiCommissionPct}%'
                : 'BADGE SCORE: ${badge.score}/130 pts - Fee ${badge.fundiCommissionPct}%',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: badgeProgress,
              minHeight: 10,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(
                badge.badgeLevel == BadgeLevel.gold
                    ? const Color(0xFFFFD700)
                    : badge.badgeLevel == BadgeLevel.silver
                    ? const Color(0xFFC0C0C0)
                    : badge.badgeLevel == BadgeLevel.bronze
                    ? const Color(0xFFCD7F32)
                    : Colors.black45,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badgeNextText,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          if (badge.isTrialGold) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'TRIAL GOLD ends ${badge.trialExpiresAt?.day}/${badge.trialExpiresAt?.month}. Complete profile + KYC to keep GOLD at 5% fee, else you drop to BRONZE 10%.',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildChecklist(),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to increase score (130 max):',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        _check(badge.breakdown['kyc'] == 10, 'KYC verified (10pts)'),
        _check(
          (badge.breakdown['profileComplete'] ?? 0) >= 10,
          'My Advert 100% (ID + Good Conduct + Cert + Photo + Bio) (10pts)',
        ),
        _check(
          badge.breakdown['jobs'] != null && badge.breakdown['jobs']! >= 5,
          'Jobs completed',
        ),
        _check(
          badge.breakdown['rating'] != null && badge.breakdown['rating']! >= 15,
          'Rating 4.5+ (20pts)',
        ),
        _check(
          (badge.breakdown['cancellations'] ?? 10) >= 8,
          'No cancellations (10pts)',
        ),
        _check(
          (badge.breakdown['fraud'] ?? 10) == 10,
          'No fraud reports (10pts)',
        ),
        _check(
          badge.breakdown['fastResponse'] == 10,
          'Fast response <5min bid, <10min chat (10pts)',
        ),
        _check(
          (badge.breakdown['referral'] ?? 0) > 0,
          'Referrals - ask clients to refer (${(badge.referralRate * 100).toStringAsFixed(0)}%)',
        ),
      ],
    );
  }

  Widget _check(bool done, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 12,
            color: done ? Colors.green : Colors.black26,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: done ? Colors.black87 : Colors.black45,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
