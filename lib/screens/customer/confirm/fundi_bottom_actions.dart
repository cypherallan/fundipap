import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConfirmFundiBottomActions extends StatelessWidget {
  final Map<String, dynamic> bidData;
  final int labor;
  final int transportFee;
  final int total;
  final double distanceKm;
  final String transportMode;
  final VoidCallback onReject;
  final VoidCallback onConfirm;
  final VoidCallback onReport;

  const ConfirmFundiBottomActions({
    super.key,
    required this.bidData,
    this.labor = 0,
    this.transportFee = 0,
    this.total = 0,
    this.distanceKm = 0,
    this.transportMode = 'boda',
    required this.onReject,
    required this.onConfirm,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    int fundiAsk =
        (bidData['amount'] ?? bidData['bidAmount'] ?? bidData['price'] ?? 0)
            .toInt();
    int displayLabor = labor > 0 ? labor : fundiAsk;
    int displayTotal = total > 0 ? total : fundiAsk;
    int displayTransport = transportFee;

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Breakdown - NEW
            if (displayTotal > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Labor', style: GoogleFonts.inter(fontSize: 11)),
                        Text(
                          'KES $displayLabor',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transport ${distanceKm > 0 ? '(${distanceKm.toStringAsFixed(1)}km $transportMode)' : '($transportMode)'}',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        Text(
                          'KES $displayTransport',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL TO LOCK TO ESCROW',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'KES $displayTotal',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      side: const BorderSide(color: FundipapColors.redAlert),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onReject,
                    child: Text(
                      'REJECT',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        color: FundipapColors.redAlert,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.blackGray,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onConfirm,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'CONFIRM • KES $displayTotal',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        if (displayTransport > 0)
                          Text(
                            'incl. KES $displayTransport transport',
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onReport,
              icon: const Icon(
                Icons.flag_outlined,
                size: 14,
                color: FundipapColors.redAlert,
              ),
              label: Text(
                'Report fraud / scam',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: FundipapColors.redAlert,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
