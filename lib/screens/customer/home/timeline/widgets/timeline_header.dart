import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';

class TimelineHeader extends StatelessWidget {
  final String fundiName;
  final String trade;

  const TimelineHeader({
    super.key,
    required this.fundiName,
    required this.trade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: FundipapColors.blackGray,
            child: Text(
              fundiName.isNotEmpty ? fundiName[0].toUpperCase() : 'F',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fundiName,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                trade,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
