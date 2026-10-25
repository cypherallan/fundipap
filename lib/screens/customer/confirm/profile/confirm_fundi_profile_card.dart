import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/fundi_badge_chip.dart';
import '../../../fundi/services/fundi_badge_service.dart';

class ConfirmFundiProfileCard extends StatelessWidget {
  final Map<String, dynamic> combined;
  const ConfirmFundiProfileCard({super.key, required this.combined});

  @override
  Widget build(BuildContext context) {
    var name = combined['name'] ?? combined['fundiName'] ?? 'Fundi';
    var photo = combined['photoUrl'];
    var profession = combined['profession'] ?? combined['skill'] ?? 'Fundi';
    var bio = (combined['bio'] ?? combined['about'] ?? 'No bio yet').toString();

    String badgeStr = (combined['badgeLevel'] ?? 'none').toString();
    BadgeLevel level = BadgeLevel.values.firstWhere(
      (e) => e.name == badgeStr,
      orElse: () => BadgeLevel.none,
    );
    bool isVerified =
        combined['isVerifiedFundi'] == true || combined['verified'] == true;
    int referrals = (combined['referralCount'] ?? 0) as int;
    int jobsDone =
        (combined['jobsDone'] ?? combined['completedJobs'] ?? 0) as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: FundipapColors.primaryYellow,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isVerified)
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    Text(
                      profession,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: FundipapColors.blackGray,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FundiBadgeChip(
                      level: level,
                      isVerified: isVerified,
                      referralCount: referrals,
                      jobsDone: jobsDone,
                      hideCommission: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ExpandableBio(bio: bio),
        ],
      ),
    );
  }
}

class _ExpandableBio extends StatefulWidget {
  final String bio;
  const _ExpandableBio({required this.bio});
  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isLong = widget.bio.length > 120 || widget.bio.split('\n').length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.bio,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.black54,
            height: 1.4,
          ),
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (isLong) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'See less' : 'See more',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: FundipapColors.primaryYellow,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
