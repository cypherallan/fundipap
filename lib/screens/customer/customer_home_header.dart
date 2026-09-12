import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class CustomerHomeHeader extends StatelessWidget {
  final Map<String, dynamic>? me;
  final int profilePct;
  final int completedJobs;
  final VoidCallback onProfileTap;

  const CustomerHomeHeader({
    super.key,
    required this.me,
    required this.profilePct,
    required this.completedJobs,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final username = me?['username'] ?? '';
    final name = me?['name'] ?? me?['fullName'] ?? 'Client';
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
                        (name.isNotEmpty ? name[0].toUpperCase() : 'C'),
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
              child: GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: FundipapColors.primaryYellow,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 12, color: Colors.black),
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
                'Habari, $name',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (username.toString().isNotEmpty)
                Text(
                  '@$username',
                  style: GoogleFonts.inter(
                    color: FundipapColors.primaryYellow,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              Text(
                'CLIENT • $completedJobs jobs posted',
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  '$profilePct% PROFILE',
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
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
