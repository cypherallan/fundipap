import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'price_calculator.dart';
import '../services/fundi_badge_service.dart'; // adjust path

class CurrentPriceCard extends StatelessWidget {
  final PriceCalculator calc;
  final BadgeResult? badge;
  final int clientFeePct;
  final int fundiFeePct;

  const CurrentPriceCard({
    super.key,
    required this.calc,
    required this.badge,
    required this.clientFeePct,
    required this.fundiFeePct,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: Labour KES ${calc.oldLabor} + Transport KES ${calc.transport} = KES ${calc.oldLabor + calc.transport}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          Text(
            'Transport does not change. App Maintenance Cost = $clientFeePct% client, $fundiFeePct% you (${badge?.badgeLevel.name ?? 'bronze'}).',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
