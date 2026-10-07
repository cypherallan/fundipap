import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';

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

  int _calcTransport(Map<String, dynamic> job, Map<String, dynamic> bid) {
    double dist = 0.5;
    if (job['distanceKm'] != null) dist = (job['distanceKm'] as num).toDouble();
    if (bid['distanceKm'] != null) dist = (bid['distanceKm'] as num).toDouble();
    if (bid['transportFee'] != null) return _toInt(bid['transportFee']);
    if (job['transportFee'] != null && _toInt(job['transportFee']) > 0)
      return _toInt(job['transportFee']);
    if (dist <= 1.0) return 100;
    return (dist * 80).round().clamp(100, 2000);
  }

  @override
  Widget build(BuildContext context) {
    final status = (bidData['status'] ?? '').toString();
    final isAcceptedCounter =
        status.contains('counter_accepted_by_fundi') ||
        status == 'counter_accepted';
    final isMyCounter =
        status == 'countered' &&
        (bidData['counterBy'] ?? bidData['lastCounterBy'] ?? '') == 'client';

    int effectiveLabor = _toInt(
      bidData['agreedPrice'] ??
          bidData['effectiveLabor'] ??
          bidData['clientCounterAmount'] ??
          bidData['lastCounterAmount'] ??
          bidData['amount'] ??
          bidData['bidAmount'] ??
          bidData['price'] ??
          0,
    );
    int originalFundiAsk = _toInt(
      bidData['price'] ?? bidData['bidAmount'] ?? bidData['amount'] ?? 0,
    );

    int clientOffer = _toInt(
      jobData['systemPriceAvg'] ??
          jobData['budget'] ??
          jobData['offeredPrice'] ??
          jobData['budgetMin'] ??
          0,
    );
    String note = (bidData['note'] ?? '').toString();

    int transport = _calcTransport(jobData, bidData);
    int clientAppFee = (effectiveLabor * 0.05).round();
    int totalToLock = effectiveLabor + transport + clientAppFee;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAcceptedCounter
            ? Colors.green.shade50
            : FundipapColors.primaryYellow.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAcceptedCounter
              ? Colors.green.shade400
              : FundipapColors.primaryYellow,
          width: isAcceptedCounter ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bid for: ${jobData['title'] ?? jobData['subcategoryName'] ?? 'Job'}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isAcceptedCounter)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ACCEPTED COUNTER',
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
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
                    isAcceptedCounter
                        ? 'Your counter (Labour):'
                        : isMyCounter
                        ? 'Your counter:'
                        : 'Fundi asks (Labour):',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    'KES $effectiveLabor',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isAcceptedCounter
                          ? Colors.green.shade800
                          : Colors.black,
                    ),
                  ),
                  if (isAcceptedCounter && originalFundiAsk != effectiveLabor)
                    Text(
                      'was KES $originalFundiAsk',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.black45,
                        decoration: TextDecoration.lineThrough,
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
                _row('Labour:', 'KES $effectiveLabor'),
                _row('Transport (min 100):', 'KES $transport', highlight: true),
                _row(
                  'App Maintenance (5% of $effectiveLabor):',
                  'KES $clientAppFee',
                ),
                const Divider(height: 12),
                _row('TOTAL TO LOCK:', 'KES $totalToLock', bold: true),
                const SizedBox(height: 4),
                if (isAcceptedCounter)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'You countered KES $effectiveLabor, fundi accepted. You pay labour + transport + 5% fee = KES $totalToLock to escrow.',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
