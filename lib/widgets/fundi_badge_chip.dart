import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fundi_badge_service.dart';

class FundiBadgeChip extends StatelessWidget {
  final BadgeLevel level;
  final FundiLevel fundiLevel;
  final bool isVerified;
  final bool isTrialGold;
  final DateTime? trialExpiresAt; // ADD THIS
  final int referralCount;
  final int jobsDone;
  final int commissionPct;
  final bool showLevel;
  final bool compact;
  final bool hideCommission;

  const FundiBadgeChip({
    super.key,
    required this.level,
    this.fundiLevel = FundiLevel.L1_NEW,
    this.isVerified = false,
    this.isTrialGold = false,
    this.trialExpiresAt, // ADD THIS
    this.referralCount = 0,
    this.jobsDone = 0,
    this.commissionPct = 15, // none = 15% default
    this.showLevel = true,
    this.compact = false,
    this.hideCommission = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;
    switch (level) {
      case BadgeLevel.gold:
        bg = const Color(0xFFFFD700);
        fg = Colors.black;
        label = isTrialGold ? 'GOLD TRIAL' : 'GOLD';
        icon = Icons.emoji_events;
        break;
      case BadgeLevel.silver:
        bg = Colors.grey.shade300;
        fg = Colors.black87;
        label = 'SILVER';
        icon = Icons.military_tech;
        break;
      case BadgeLevel.bronze:
        bg = const Color(0xFFCD7F32);
        fg = Colors.white;
        label = 'BRONZE';
        icon = Icons.workspace_premium;
        break;
      case BadgeLevel.none:
        bg = Colors.grey.shade100;
        fg = Colors.black54;
        label = 'NEW';
        icon = Icons.new_releases_outlined;
    }

    String levelLabel = '';
    switch (fundiLevel) {
      case FundiLevel.L1_NEW:
        levelLabel = 'L1';
        break;
      case FundiLevel.L2_HUSTLER:
        levelLabel = 'L2';
        break;
      case FundiLevel.L3_PRO:
        levelLabel = 'L3';
        break;
      case FundiLevel.L4_ELITE:
        levelLabel = 'L4';
        break;
    }

    // FIX: calculate days left
    int trialDaysLeft = 0;
    if (isTrialGold && trialExpiresAt != null) {
      trialDaysLeft = trialExpiresAt!
          .difference(DateTime.now())
          .inDays
          .clamp(0, 14);
      if (trialDaysLeft == 0) trialDaysLeft = 1;
    }

    double referralRate = jobsDone > 0 ? referralCount / jobsDone : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLevel)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              levelLabel,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 9,
                color: Colors.white,
              ),
            ),
          ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: isTrialGold
                ? Border.all(color: Colors.black, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: fg,
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, size: 12, color: Colors.blue.shade700),
              ],
              if (isTrialGold) ...[
                const SizedBox(width: 4),
                Text(
                  '${trialDaysLeft}D',
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!compact && !hideCommission) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: commissionPct == 5
                  ? Colors.green.shade50
                  : commissionPct == 8
                  ? Colors.grey.shade200
                  : commissionPct == 10
                  ? Colors.orange.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: commissionPct == 5
                    ? Colors.green
                    : commissionPct == 8
                    ? Colors.grey
                    : commissionPct == 10
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
            child: Text(
              '$commissionPct% fee',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: commissionPct == 5
                    ? Colors.green.shade800
                    : commissionPct == 8
                    ? Colors.black87
                    : commissionPct == 10
                    ? Colors.orange.shade800
                    : Colors.red.shade800,
              ),
            ),
          ),
        ],
        if (jobsDone > 0 && !compact) ...[
          const SizedBox(width: 6),
          Text(
            '$referralCount/$jobsDone • ${(referralRate * 100).toStringAsFixed(0)}% would refer',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ],
    );
  }
}
