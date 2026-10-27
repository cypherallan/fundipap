import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart'; // adjust path
import 'bill_row.dart';
import 'price_calculator.dart';
import 'part_needed.dart';

class BillSummaryCard extends StatelessWidget {
  final PriceCalculator calc;
  final bool needsLabor;
  final bool needsParts;
  final List<PartNeeded> partsNeeded;

  const BillSummaryCard({
    super.key,
    required this.calc,
    required this.needsLabor,
    required this.needsParts,
    required this.partsNeeded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FundipapColors.blackGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary - NEW PRICE',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          BillRow(label: 'Old Labour:', value: 'KES ${calc.oldLabor}'),
          BillRow(
            label: 'Extra Labour:',
            value: 'KES ${calc.effectiveExtraLabor}',
            highlight: true,
          ),
          BillRow(
            label: 'New Labour Total:',
            value: 'KES ${calc.newLaborTotal}',
            highlight: true,
          ),
          BillRow(label: 'Transport (same):', value: 'KES ${calc.transport}'),
          const Divider(color: Colors.white24),
          BillRow(
            label: 'Old Total Paid:',
            value: 'KES ${calc.oldLabor + calc.transport}',
          ),
          BillRow(
            label: 'Extra to Lock Now:',
            value: 'KES ${needsLabor ? calc.effectiveExtraLabor : 0}',
            highlightYellow: true,
          ),
          const SizedBox(height: 6),
          Text(
            needsParts
                ? 'Parts: ${partsNeeded.where((p) => p.hasName).length} items - KES ${calc.partsEstimateTotal} separate (client buys)'
                : 'No parts requested',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
