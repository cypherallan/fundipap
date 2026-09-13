import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConfirmFundiBidCard extends StatelessWidget {
  final Map<String, dynamic> jobData;
  final Map<String, dynamic> bidData;
  const ConfirmFundiBidCard({
    super.key,
    required this.jobData,
    required this.bidData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FundipapColors.primaryYellow.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FundipapColors.primaryYellow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bid for: ${jobData['title']}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Offered by you: KES ${jobData['budget']}',
                style: GoogleFonts.inter(fontSize: 11),
              ),
              Text(
                'Fundi asks: KES ${bidData['price']}',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
