import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiEarningsCard extends StatelessWidget {
  final Map<String, dynamic>? me;
  final double
  totalEarned; // MUST be sum of fundiReceives: labour - fundiAppFee + transport
  final int completedJobs;
  final int profilePct;

  const FundiEarningsCard({
    super.key,
    required this.me,
    required this.totalEarned,
    required this.completedJobs,
    required this.profilePct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FundipapColors.primaryYellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL EARNED • ONLY YOU SEE THIS',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            me == null ? 'KES --' : 'KES ${totalEarned.toStringAsFixed(0)}',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          // NEW FORMULA TEXT
          Text(
            'From $completedJobs jobs • After 5% app fee • Formula: Labour -5% + Transport = Payout',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          Text(
            'Eg: 6000 - 300 + 100 = 5800 you get, client paid 6400',
            style: GoogleFonts.inter(fontSize: 9, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat('$completedJobs', 'Done'),
              _stat('${me?['rating'] ?? 5.0}', 'Rating'),
              _stat('$profilePct%', 'Profile'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(v, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
            Text(l, style: GoogleFonts.inter(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
