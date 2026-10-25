import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../screens/fundi/services/fundi_badge_service.dart';
import 'fundi_badge_chip.dart';

class FundiLevelProgressWidget extends StatefulWidget {
  final BadgeResult badge;
  final int completedJobs;
  const FundiLevelProgressWidget({
    super.key,
    required this.badge,
    required this.completedJobs,
  });

  @override
  State<FundiLevelProgressWidget> createState() =>
      _FundiLevelProgressWidgetState();
}

class _FundiLevelProgressWidgetState extends State<FundiLevelProgressWidget> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final badge = widget.badge;
    final completedJobs = widget.completedJobs;

    double levelProgress;
    String levelNextText;

    if (badge.isTrialGold) {
      levelProgress = (completedJobs / 10).clamp(0, 1).toDouble();
      int left = 10 - completedJobs;
      levelNextText = left <= 0
          ? 'Trial ending - complete profile'
          : '$left jobs left in trial';
    } else if (badge.fundiLevel == FundiLevel.L1_NEW) {
      levelProgress = (completedJobs / 10).clamp(0, 1).toDouble();
      levelNextText = '${10 - completedJobs} jobs to L2 HUSTLER';
    } else if (badge.fundiLevel == FundiLevel.L2_HUSTLER) {
      levelProgress = ((completedJobs - 10) / 40).clamp(0, 1).toDouble();
      levelNextText = '${50 - completedJobs} jobs to L3 PRO';
    } else if (badge.fundiLevel == FundiLevel.L3_PRO) {
      levelProgress = ((completedJobs - 50) / 50).clamp(0, 1).toDouble();
      levelNextText = '${100 - completedJobs} jobs to L4 ELITE';
    } else {
      levelProgress = 1.0;
      levelNextText = 'ELITE MAX';
    }

    double badgeProgress = badge.isTrialGold
        ? (completedJobs / 10).clamp(0, 1).toDouble()
        : (badge.score / 130).clamp(0, 1).toDouble();

    String badgeNextText;
    if (badge.isTrialGold) {
      badgeNextText = '$completedJobs/10 to L2 - keep profile complete';
    } else if (badge.badgeLevel == BadgeLevel.none) {
      badgeNextText = '${badge.pointsToNextBadge} pts to BRONZE';
    } else if (badge.badgeLevel == BadgeLevel.bronze) {
      badgeNextText = '${badge.pointsToNextBadge} pts to SILVER';
    } else if (badge.badgeLevel == BadgeLevel.silver) {
      badgeNextText = '${badge.pointsToNextBadge} pts to GOLD';
    } else {
      badgeNextText = 'GOLD MAX - 5% fee';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Growth Path',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'LEVEL: ${badge.fundiLevel.name} ($completedJobs jobs) - $levelNextText',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                FundiBadgeChip(
                  level: badge.isTrialGold ? BadgeLevel.gold : badge.badgeLevel,
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
          ),

          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 6,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(FundipapColors.blackGray),
            ),
          ),

          if (expanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
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
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
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
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
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
                        'TRIAL GOLD ends ${badge.trialExpiresAt?.day}/${badge.trialExpiresAt?.month}. Complete profile + KYC to keep GOLD at 5% fee.',
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
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    final badge = widget.badge;
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
          'My Advert 100% (10pts)',
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
          'Fast response <5min bid (10pts)',
        ),
        _check(
          (badge.breakdown['referral'] ?? 0) > 0,
          'Referrals (${(badge.referralRate * 100).toStringAsFixed(0)}%)',
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
