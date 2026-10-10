import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FundiJobCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMatch;
  final VoidCallback? onBid;
  final VoidCallback onTap;
  final double? distanceKm;
  final bool hasBid;
  final String? bidStatus;

  const FundiJobCard({
    super.key,
    required this.data,
    required this.isMatch,
    required this.onBid,
    required this.onTap,
    this.distanceKm,
    this.hasBid = false,
    this.bidStatus,
  });

  @override
  Widget build(BuildContext context) {
    final clientName =
        data['customerUsername'] ??
        data['customerName'] ??
        data['clientName'] ??
        'Client';
    final offered =
        data['budget'] ?? data['offeredPrice'] ?? data['amount'] ?? 0;
    final budgetText = 'KES $offered';
    final distanceText = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)}km away'
        : 'Calculating...';

    // NEW: detect cancellation directly from job data
    bool isCancelled =
        (data['cancelled'] == true) ||
        (data['autoCancelled'] == true) ||
        (data['status'] ?? '').toString().toLowerCase().contains('cancel');

    // NEW: check bid-level cancellation
    bool bidCancelledByClient =
        (bidStatus ?? data['bidStatus'] ?? '').toString() ==
        'cancelled_by_client';
    if (bidCancelledByClient) {
      isCancelled = true;
    }

    String cancelledBy = (data['cancelledBy'] ?? '').toString().toLowerCase();
    bool clientCancelled =
        (isCancelled && cancelledBy == 'client') || bidCancelledByClient;
    bool fundiCancelled = isCancelled && cancelledBy == 'fundi';
    bool systemCancelled =
        isCancelled &&
        (cancelledBy == 'system' || data['autoCancelled'] == true);
    String cancelReason =
        (data['fundiCancelReason'] ?? data['cancelReason'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCancelled
              ? Colors.red.shade50
              : hasBid
              ? const Color(0xFFF0FFF0)
              : isMatch
              ? Colors.white
              : Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: isCancelled
              ? Border.all(color: Colors.red.shade300, width: 1.2)
              : hasBid
              ? Border.all(color: FundipapColors.greenSuccess, width: 1.5)
              : isMatch
              ? Border.all(color: FundipapColors.primaryYellow, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // inside build, after you define clientCancelled

            // CANCELLED BANNER FOR FUNDI
            if (isCancelled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: clientCancelled
                      ? Colors.orange.shade100
                      : fundiCancelled
                      ? Colors.grey.shade200
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: clientCancelled
                        ? Colors.orange.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      clientCancelled
                          ? Icons.person_off
                          : fundiCancelled
                          ? Icons.cancel_outlined
                          : Icons.warning_amber,
                      size: 14,
                      color: clientCancelled
                          ? Colors.orange.shade800
                          : Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        clientCancelled
                            ? 'Client cancelled this job${cancelReason.isNotEmpty && cancelReason != 'Cancelled before escrow' ? ': $cancelReason' : ''}'
                            : fundiCancelled
                            ? 'You cancelled this job'
                            : systemCancelled
                            ? 'Job auto-cancelled: $cancelReason'
                            : 'This job was cancelled',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: clientCancelled
                              ? Colors.orange.shade900
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                    // NEW X BUTTON
                    if (bidCancelledByClient) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () async {
                          try {
                            var uid = FirebaseAuth.instance.currentUser!.uid;
                            await FirebaseFirestore.instance
                                .collection('jobs')
                                .doc(data['id'].toString())
                                .collection('bids')
                                .doc(uid)
                                .update({'deletedForFundi': true});
                          } catch (_) {}
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Client row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: FundipapColors.blackGray,
                  child: Text(
                    clientName[0].toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    clientName,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        distanceText,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isMatch
                        ? FundipapColors.primaryYellow
                        : Colors.black12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (data['category'] ?? 'General').toString().toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isMatch) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: FundipapColors.greenSuccess,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FOR YOU',
                      style: GoogleFonts.montserrat(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                if (hasBid && !isCancelled) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: FundipapColors.greenSuccess,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check, size: 10, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          'BID PLACED',
                          style: GoogleFonts.montserrat(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  budgetText,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['title'] ?? 'Job',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data['location'] ?? data['address'] ?? '',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            // BID BUTTON OR CANCELLED STATE
            if (isCancelled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  clientCancelled
                      ? 'Client cancelled - moved to cancelled tab'
                      : 'Cancelled',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              )
            else if (hasBid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: FundipapColors.greenSuccess.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: FundipapColors.greenSuccess.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.hourglass_top,
                      size: 14,
                      color: FundipapColors.greenSuccess,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You have placed a bid on this job. Wait for client feedback',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FundipapColors.greenSuccess,
                      ),
                    ),
                  ],
                ),
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
                  ),
                  onPressed: onBid,
                  child: Text(
                    'Place Bid',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
