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

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  // YOUR RULE: min 100 if <=1km
  int _calcTransport(Map<String, dynamic> job, Map<String, dynamic> bid) {
    double dist = 0.5; // default <=1km
    if (job['distanceKm'] != null) dist = (job['distanceKm'] as num).toDouble();
    if (bid['distanceKm'] != null) dist = (bid['distanceKm'] as num).toDouble();
    // if you already saved transport at bid time, use it
    if (bid['transportFee'] != null) return _toInt(bid['transportFee']);
    if (job['transportFee'] != null && _toInt(job['transportFee']) > 0) {
      return _toInt(job['transportFee']);
    }
    if (dist <= 1.0) return 100;
    return (dist * 80).round().clamp(100, 2000); // your per km maths
  }

  @override
  Widget build(BuildContext context) {
    int fundiAsk = _toInt(
      bidData['amount'] ?? bidData['bidAmount'] ?? bidData['price'] ?? 0,
    );
    int clientOffer = _toInt(
      jobData['systemPriceAvg'] ??
          jobData['budget'] ??
          jobData['offeredPrice'] ??
          jobData['budgetMin'] ??
          0,
    );
    String note = (bidData['note'] ?? '').toString();

    int transport = _calcTransport(jobData, bidData); // FIX: min 100 now, not 0
    int clientAppFee = (fundiAsk * 0.05).round();
    int totalToLock = fundiAsk + transport + clientAppFee; // 5000+100+250=5350
    int fundiGets =
        fundiAsk -
        clientAppFee +
        transport; // 5000-250+100=4850? Wait your logic: labour - fee + transport

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
          const SizedBox(height: 10),
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
                    'Fundi asks (Labour):',
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _row('Labour:', 'KES $fundiAsk'),
                _row('Transport (min 100):', 'KES $transport', highlight: true),
                _row('App fee (5%):', 'KES $clientAppFee'),
                const Divider(height: 12),
                _row('TOTAL TO LOCK:', 'KES $totalToLock', bold: true),
                const SizedBox(height: 4),
                Text(
                  'Fundi will receive KES $fundiGets after fee',
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.black54),
                ),
              ],
            ),
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

  Widget _row(String l, String v, {bool bold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: highlight ? Colors.orange.shade800 : Colors.black87,
            ),
          ),
          Text(
            v,
            style: GoogleFonts.montserrat(
              fontSize: bold ? 12 : 11,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? Colors.orange.shade800 : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
