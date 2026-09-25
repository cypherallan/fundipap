import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConfirmFundiBottomActions extends StatelessWidget {
  final Map<String, dynamic> bidData;
  final int labor;
  final int transportFee;
  final int appFee; // NEW: 5% client sees = 250
  final int total; // 5350
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
    this.appFee = 0,
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
    int displayTransport = transportFee;
    int displayAppFee = appFee > 0
        ? appFee
        : (displayLabor * 0.05).round(); // 250
    int displayTotal = total > 0
        ? total
        : displayLabor + displayTransport + displayAppFee; // 5350

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (displayTotal > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    _row('Fundi labour charges:', 'KES $displayLabor'),
                    SizedBox(height: 6),
                    _row('Transport cost:', 'KES $displayTransport'),
                    SizedBox(height: 6),
                    _row('App maintenance cost:', 'KES $displayAppFee'),
                    Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total to pay:',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'KES $displayTotal',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This total will be locked and paid',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
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
                    child: Text(
                      'CONFIRM • KES $displayTotal',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
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

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
