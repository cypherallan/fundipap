import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget feeRow(String l, String v, {bool bold = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
        Text(
          v,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
