import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/fundi_badge_chip.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../models/customer_home_models.dart';
import '../../../confirm/confirm_fundi_page.dart';
import '../../timeline/customer_fundi_timeline_page.dart';
import '../../timeline/timeline_actions.dart';

class PendingBidCard extends StatelessWidget {
  final BidWithFundi bid;
  final String jobId;
  final Map<String, dynamic> jobData;
  final BuildContext? parentContextForNav;
  final BuildContext? sheetContextForClose;

  const PendingBidCard({
    super.key,
    required this.bid,
    required this.jobId,
    required this.jobData,
    this.parentContextForNav,
    this.sheetContextForClose,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> openConfirm() async {
      if (sheetContextForClose != null && sheetContextForClose!.mounted) {
        Navigator.pop(sheetContextForClose!);
      }
      final navContext = parentContextForNav ?? context;
      final confirmed = await Navigator.push<bool>(
        navContext,
        MaterialPageRoute(
          builder: (_) => ConfirmFundiPage(
            jobId: jobId,
            jobData: jobData,
            bidId: bid.bidDoc.id,
            bidData: bid.bid,
          ),
        ),
      );
      if (confirmed == true && navContext.mounted) {
        Navigator.pushReplacement(
          navContext,
          MaterialPageRoute(
            builder: (_) => CustomerFundiTimelinePage(
              jobId: jobId,
              fundiName: bid.bid['fundiName'] ?? 'Fundi',
              trade: (jobData['category'] ?? '').toString(),
              jobData: jobData,
            ),
          ),
        );
      }
    }

    Future<void> proceedWithFundi() async {
      final navContext = parentContextForNav ?? context;
      final int labour =
          ((bid.bid['agreedPrice'] ??
                      bid.bid['clientCounterAmount'] ??
                      bid.bid['lastCounterAmount'] ??
                      bid.bid['price'] ??
                      0)
                  as num)
              .toInt();
      final int transport = ((jobData['transportFee'] ?? 100) as num).toInt();
      final int total = labour + transport + (labour * 0.05).round(); // 5350
      try {
        if (sheetContextForClose != null && sheetContextForClose!.mounted)
          Navigator.pop(sheetContextForClose!);
        // show loading
        showDialog(
          context: navContext,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        await TimelineActions.proceedWithFundi(
          jobId,
          (bid.bid['fundiId'] ?? bid.bidDoc.id).toString(),
          total,
        );
        if (navContext.mounted) Navigator.pop(navContext); // close loading
        if (navContext.mounted) {
          Navigator.pushReplacement(
            navContext,
            MaterialPageRoute(
              builder: (_) => CustomerFundiTimelinePage(
                jobId: jobId,
                fundiName: bid.bid['fundiName'] ?? 'Fundi',
                trade: (jobData['category'] ?? '').toString(),
                jobData: jobData,
              ),
            ),
          );
        }
      } catch (e) {
        if (navContext.mounted) Navigator.pop(navContext);
        if (navContext.mounted)
          ScaffoldMessenger.of(
            navContext,
          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }

    String distanceText = bid.distanceKm > 0
        ? ' (${bid.distanceKm.toStringAsFixed(1)} km)'
        : '';

    final status = (bid.bid['status'] ?? '').toString();
    final counterBy = (bid.bid['counterBy'] ?? bid.bid['lastCounterBy'] ?? '')
        .toString();
    final isCountered = status == 'countered';
    final isMyCounter = isCountered && counterBy == 'client';
    final isFundiCounter = isCountered && counterBy == 'fundi';
    final isAcceptedCounter =
        status == 'counter_accepted_by_fundi' ||
        status == 'counter_accepted' ||
        status == 'counter_accepted_by_fundi_pending';

    final myCounterAmt =
        ((bid.bid['clientCounterAmount'] ?? bid.bid['lastCounterAmount'] ?? 0)
                as num)
            .toInt();
    final fundiCounterAmt =
        ((bid.bid['fundiCounterAmount'] ?? bid.bid['lastCounterAmount'] ?? 0)
                as num)
            .toInt();
    final acceptedAmt =
        ((bid.bid['agreedPrice'] ??
                    bid.bid['clientCounterAmount'] ??
                    myCounterAmt)
                as num)
            .toInt();
    final fundiName = (bid.bid['fundiName'] ?? 'Fundi').toString();

    // Colors: accepted counter = GREEN distinct from rest
    Color bg = const Color(0xFFF8F8F8);
    Color border = Colors.black12;
    if (isAcceptedCounter) {
      bg = Colors.green.shade50;
      border = Colors.green.shade400;
    } else if (isMyCounter) {
      bg = Colors.transparent;
      border = Colors.transparent;
    }

    return InkWell(
      onTap: isMyCounter || isAcceptedCounter ? null : openConfirm,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: isAcceptedCounter ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black,
                  child: Text(
                    (fundiName)[0],
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$fundiName$distanceText',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (bid.verified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 14,
                                color: Colors.blue,
                              ),
                            ),
                          if (isAcceptedCounter)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ACCEPTED YOUR COUNTER',
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 12,
                            color: Colors.amber.shade700,
                          ),
                          Text(
                            '${bid.rating.toStringAsFixed(1)}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${bid.referrals} referrals • ${bid.jobsDone} jobs',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FundiBadgeChip(
                  level: bid.level,
                  isVerified: bid.verified,
                  referralCount: bid.referrals,
                  jobsDone: bid.jobsDone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bid',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  'KES ${bid.bid['price'] ?? bid.bid['amount'] ?? bid.bid['bidAmount'] ?? 0}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (isAcceptedCounter)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 18,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$fundiName accepted your countered price KES $acceptedAmt for the job',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.greenSuccess,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: proceedWithFundi,
                      child: Text(
                        'PROCEED WITH ${fundiName.toUpperCase()} • PAY KES ${acceptedAmt + ((jobData['transportFee'] ?? 100) as num).toInt() + (acceptedAmt * 0.05).round()}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (isMyCounter)
              OrangeAnimatedWaitingCard(
                title: 'Counter offer sent • KES $myCounterAmt',
                message:
                    'Waiting for fundi to respond to your countered offer KES $myCounterAmt',
              )
            else if (isFundiCounter)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_alt,
                          size: 18,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fundi countered: KES $fundiCounterAmt - Tap to respond',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.blackGray,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: openConfirm,
                      child: Text(
                        'View counter & React',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FundipapColors.blackGray,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: openConfirm,
                  child: Text(
                    'View fundi & React to bid',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
