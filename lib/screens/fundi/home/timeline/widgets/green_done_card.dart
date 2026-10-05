import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget greenDoneCard({
  required String title,
  required String message,
  IconData icon = Icons.check_circle,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.shade300, width: 1.2),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green.shade800, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(message, style: GoogleFonts.inter(fontSize: 11)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 12,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Done',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
