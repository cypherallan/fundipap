import 'package:flutter/material.dart';
import 'fundi_home_header.dart';
import 'fundi_profile_banners.dart';
import 'fundi_earnings_card.dart';
import '../fundi_profile.dart';

class FundiHomeHeaderSection extends StatelessWidget {
  final Map<String, dynamic>? me;
  final int profilePct;
  final int completedJobs;
  final double totalEarned;
  final VoidCallback onReloadMe;

  const FundiHomeHeaderSection({
    super.key,
    required this.me,
    required this.profilePct,
    required this.completedJobs,
    required this.totalEarned,
    required this.onReloadMe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: FundiHomeHeader(
            me: me,
            profilePct: profilePct,
            completedJobs: completedJobs,
            onProfileTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FundiProfile()),
              );
              onReloadMe();
            },
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: profilePct < 100
              ? FundiProfileIncompleteBanner(profilePct: profilePct)
              : const FundiProfileCompleteBanner(),
        ),
        if (me?['bio'] != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FundiBioCard(bio: me!['bio']),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FundiEarningsCard(
            me: me,
            totalEarned: totalEarned,
            completedJobs: completedJobs,
            profilePct: profilePct,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
