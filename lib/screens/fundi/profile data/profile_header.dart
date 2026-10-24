import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ProfileHeader extends StatelessWidget {
  final Map combined;
  final int profilePct;
  final bool uploadingPhoto;
  final VoidCallback onChangePhoto;
  final int jobsDone;
  final double rating;
  final int ratingCount;
  final int fraud;

  const ProfileHeader({
    super.key,
    required this.combined,
    required this.profilePct,
    required this.uploadingPhoto,
    required this.onChangePhoto,
    required this.jobsDone,
    required this.rating,
    required this.ratingCount,
    required this.fraud,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      value: profilePct / 100,
                      strokeWidth: 4,
                      backgroundColor: Colors.black12,
                      valueColor: AlwaysStoppedAnimation(
                        profilePct == 100
                            ? FundipapColors.greenSuccess
                            : FundipapColors.primaryYellow,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: FundipapColors.primaryYellow,
                      backgroundImage: combined['photoUrl'] != null
                          ? NetworkImage(combined['photoUrl'])
                          : null,
                      child: combined['photoUrl'] == null
                          ? Text(
                              (combined['name'] ?? 'F')[0].toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 30,
                              ),
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onChangePhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FundipapColors.blackGray,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (uploadingPhoto)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                combined['name'] ?? 'Fundi',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                '$profilePct% Complete ${profilePct == 100 ? '• VERIFIED' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: profilePct == 100
                      ? FundipapColors.greenSuccess
                      : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: onChangePhoto,
                child: Text(
                  combined['photoUrl'] == null
                      ? 'Set Profile Photo (+15%)'
                      : 'Change Profile Photo',
                  style: GoogleFonts.montserrat(
                    color: FundipapColors.primaryYellow,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: profilePct / 100,
          color: profilePct == 100
              ? FundipapColors.greenSuccess
              : FundipapColors.primaryYellow,
          backgroundColor: Colors.black12,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat('$jobsDone', 'Jobs Done'),
            const SizedBox(width: 8),
            _stat('${rating.toStringAsFixed(1)}★ ($ratingCount)', 'Rating'),
            const SizedBox(width: 8),
            _stat('$fraud', 'Fraud Cases'),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info, size: 18, color: Colors.blue.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Now 24 categories. Your profile matches jobs by categoryId, not text. Select primary + other categories you can do.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String v, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            v,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
