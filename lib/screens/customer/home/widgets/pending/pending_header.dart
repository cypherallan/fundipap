import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';

class PendingHeader extends StatelessWidget {
  final int count;
  const PendingHeader({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: FundipapColors.blackGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.work_outline, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          'Pending Jobs',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: FundipapColors.primaryYellow,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
