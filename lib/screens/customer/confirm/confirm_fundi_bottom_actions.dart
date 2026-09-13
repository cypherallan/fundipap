import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConfirmFundiBottomActions extends StatelessWidget {
  final Map<String, dynamic> bidData;
  final VoidCallback onReject;
  final VoidCallback onConfirm;
  final VoidCallback onReport;
  const ConfirmFundiBottomActions({
    super.key,
    required this.bidData,
    required this.onReject,
    required this.onConfirm,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      'CONFIRM • KES ${bidData['price']}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
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
}
