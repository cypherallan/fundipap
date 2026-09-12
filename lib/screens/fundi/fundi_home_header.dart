import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FundiHomeHeader extends StatelessWidget {
  final Map<String, dynamic>? me;
  final int profilePct;
  final int completedJobs;
  final VoidCallback onProfileTap;

  const FundiHomeHeader({
    super.key,
    required this.me,
    required this.profilePct,
    required this.completedJobs,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child: CircularProgressIndicator(
                value: profilePct / 100,
                strokeWidth: 3,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  profilePct == 100
                      ? FundipapColors.greenSuccess
                      : FundipapColors.primaryYellow,
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: CircleAvatar(
                radius: 29,
                backgroundColor: FundipapColors.primaryYellow,
                backgroundImage: me?['photoUrl'] != null
                    ? NetworkImage(me!['photoUrl'])
                    : null,
                child: me?['photoUrl'] == null
                    ? Text(
                        (me?['name'] ?? 'F')[0].toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              // change InkWell to GestureDetector too
              child: GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: FundipapColors.primaryYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.add, size: 14, color: Colors.black),
                ),
              ),
            ),
            if (profilePct == 100)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: FundipapColors.greenSuccess,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Habari, ${me?['name'] ?? 'Fundi'}',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                me?['profession'] ?? me?['skill'] ?? 'Fundi',
                style: GoogleFonts.inter(
                  color: FundipapColors.primaryYellow,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              // SHOW OTHER SKILLS AS CHIPS - for your case
              if ((me?['otherSkills'] as List?)?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: (me!['otherSkills'] as List).take(4).map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        s.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: FundipapColors.primaryYellow,
                    size: 14,
                  ),
                  Text(
                    ' ${me?['rating'] ?? 4.9} • $completedJobs jobs',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                  if (profilePct == 100) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: FundipapColors.greenSuccess,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'VERIFIED',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: FundipapColors.greenSuccess,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'ONLINE',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}
