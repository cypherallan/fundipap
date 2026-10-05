import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// This is your original fundiCard from widgets/timeline_card.dart - unchanged
Widget fundiCard({
  required Color color,
  required Color border,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String message,
  required String time,
  required bool isCurrent,
  Widget? action,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(message, style: GoogleFonts.inter(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          time,
          style: GoogleFonts.inter(fontSize: 9, color: Colors.black54),
        ),
        if (action != null) ...[const SizedBox(height: 12), action],
      ],
    ),
  );
}
