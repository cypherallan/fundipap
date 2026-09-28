import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fundi_badge_service.dart';

class FundiBadgeChip extends StatelessWidget {
  final BadgeLevel level;
  final bool isVerified;
  final int referralCount;
  final int jobsDone;
  const FundiBadgeChip({
    super.key,
    required this.level,
    this.isVerified = false,
    this.referralCount = 0,
    this.jobsDone = 0,
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
        label = 'GOLD';
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

    double referralRate = jobsDone > 0 ? referralCount / jobsDone : 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
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
            ],
          ),
        ),
        if (jobsDone > 0) ...[
          const SizedBox(width: 6),
          Text(
            '$referralCount/$jobsDone referred • ${(referralRate * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

// Usage in client pending list:
// FundiBadgeChip(level: BadgeLevel.values.byName(fundi['badgeLevel'] ?? 'none'), isVerified: fundi['isVerifiedFundi'] ?? false, referralCount: fundi['referralCount'] ?? 0, jobsDone: fundi['jobsDone'] ?? fundi['completedJobs'] ?? 0)
