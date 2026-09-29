import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimelineCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final bool isDone;
  final Widget? action;
  final Widget? extra;
  final VoidCallback? onTap;

  const TimelineCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    this.isDone = false,
    this.action,
    this.extra,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isDone ? Colors.green.shade50 : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDone ? Colors.green : Colors.transparent,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isDone)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                  if (isDone) const SizedBox(width: 6),
                  Icon(icon, size: 18, color: isDone ? Colors.green : null),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isDone ? Colors.green.shade800 : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(body, style: GoogleFonts.inter(fontSize: 11)),
              if (extra != null) ...[const SizedBox(height: 6), extra!],
              if (action != null) ...[const SizedBox(height: 10), action!],
            ],
          ),
        ),
      ),
    );
  }
}
