import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConfirmFundiProfileCard extends StatelessWidget {
  final Map<String, dynamic> combined;
  const ConfirmFundiProfileCard({super.key, required this.combined});

  @override
  Widget build(BuildContext context) {
    var name = combined['name'] ?? combined['fundiName'] ?? 'Fundi';
    var photo = combined['photoUrl'];
    var profession = combined['profession'] ?? combined['skill'] ?? 'Fundi';
    var bio = combined['bio'] ?? 'No bio yet';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
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
                    if (combined['verified'] == true)
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: FundipapColors.greenSuccess,
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
                const SizedBox(height: 4),
                Text(
                  bio,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
