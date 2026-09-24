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
    int fundiAsk =
        (bidData['amount'] ?? bidData['bidAmount'] ?? bidData['price'] ?? 0)
            .toInt();
    int clientOffer =
        (jobData['systemPriceAvg'] ??
                jobData['budget'] ??
                jobData['offeredPrice'] ??
                jobData['budgetMin'] ??
                0)
            .toInt();
    String note = (bidData['note'] ?? '').toString();

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
            'Bid for: ${jobData['title'] ?? jobData['subcategoryName'] ?? 'Job'}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Market avg:',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    'KES $clientOffer',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fundi asks:',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    'KES $fundiAsk',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Fundi note: $note',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
