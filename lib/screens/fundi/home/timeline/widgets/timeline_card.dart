import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget fundiCard({
  required Color color,
  required Color border,
  required IconData icon,
  required Color iconColor,
  required String title,
  required String message,
  required String time,
  bool isDone = false,
  bool isCurrent = false,
  Widget? action,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black45,
                    ),
                  ),
                  if (isDone)
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(message, style: GoogleFonts.inter(fontSize: 11)),
              if (action != null) ...[const SizedBox(height: 10), action],
            ],
          ),
        ),
      ],
    ),
  );
}
