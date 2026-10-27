import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart'; // adjust path if needed

class BillRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool highlightYellow;
  final bool small;

  const BillRow({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.highlightYellow = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: small ? 9 : 11,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              color: highlightYellow
                  ? FundipapColors.primaryYellow
                  : Colors.white,
              fontWeight: highlight || highlightYellow
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: small
                  ? 10
                  : highlightYellow
                  ? 13
                  : 11,
            ),
          ),
        ],
      ),
    );
  }
}
