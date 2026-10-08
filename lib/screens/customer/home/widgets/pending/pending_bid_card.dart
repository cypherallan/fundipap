import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../theme/app_theme.dart';
import '../../../../../widgets/fundi_badge_chip.dart';
import '../../../../../widgets/animated_waiting_card.dart';
import '../../models/customer_home_models.dart';
import '../../../confirm/page/confirm_fundi_page.dart';
import '../../timeline/customer_fundi_timeline_page.dart';

class PendingBidCard extends StatefulWidget {
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
  State<PendingBidCard> createState() => _PendingBidCardState();
}

class _PendingBidCardState extends State<PendingBidCard> {
  double? _lastKm; // keeps distance stable, stops glitch

  FirebaseDatabase get _rtdb => FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://fundipap-global-default-rtdb.firebaseio.com',
  );

  @override
  Widget build(BuildContext context) {
    //... keep your openConfirm and cancelAccepted methods exactly same...
    Future<void> openConfirm() async {
      if (widget.sheetContextForClose != null &&
          widget.sheetContextForClose!.mounted) {
        Navigator.pop(widget.sheetContextForClose!);
      }
      final navContext = widget.parentContextForNav ?? context;
      final confirmed = await Navigator.push<bool>(
        navContext,
        MaterialPageRoute(
          builder: (_) => ConfirmFundiPage(
            jobId: widget.jobId,
            jobData: widget.jobData,
            bidId: widget.bid.bidDoc.id,
            bidData: widget.bid.bid,
          ),
        ),
      );
      if (confirmed == true && navContext.mounted) {
        Navigator.pushReplacement(
          navContext,
          MaterialPageRoute(
            builder: (_) => CustomerFundiTimelinePage(
              jobId: widget.jobId,
              fundiName: widget.bid.bid['fundiName'] ?? 'Fundi',
              trade: (widget.jobData['category'] ?? '').toString(),
              jobData: widget.jobData,
            ),
          ),
        );
      }
    }

    Future<void> cancelAccepted() async {
      final navContext = widget.parentContextForNav ?? context;
      final bool? ok = await showDialog<bool>(
        context: navContext,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Cancel counter?',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          content: Text(
            '${widget.bid.bid['fundiName'] ?? 'Fundi'} accepted your KES ${((widget.bid.bid['agreedPrice'] ?? widget.bid.bid['clientCounterAmount'] ?? 0) as num).toInt()} counter. Do you want to cancel?',
            style: GoogleFonts.inter(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Cancel',
                style: GoogleFonts.montserrat(
                  color: Colors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        if (navContext.mounted)
          showDialog(
            context: navContext,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        final bidId = widget.bid.bidDoc.id;
        final fundiId = (widget.bid.bid['fundiId'] ?? bidId).toString();
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .collection('bids')
            .doc(bidId)
            .update({
              'status': 'cancelled_by_client',
              'clientCancelledAt': FieldValue.serverTimestamp(),
            });
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'counterAcceptedBy': FieldValue.arrayRemove([fundiId]),
              'counterAcceptedBids': FieldValue.arrayRemove([bidId]),
              'lastCounterAcceptedBy': FieldValue.delete(),
            });
        if (navContext.mounted) Navigator.pop(navContext);
        if (navContext.mounted)
          ScaffoldMessenger.of(navContext).showSnackBar(
            const SnackBar(content: Text('Cancelled. Job stays pending.')),
          );
      } catch (e) {
        if (navContext.mounted) Navigator.pop(navContext);
        if (navContext.mounted)
          ScaffoldMessenger.of(
            navContext,
          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }

    final status = (widget.bid.bid['status'] ?? '').toString();
    final counterBy =
        (widget.bid.bid['counterBy'] ?? widget.bid.bid['lastCounterBy'] ?? '')
            .toString();
    final isCountered = status == 'countered';
    final isMyCounter = isCountered && counterBy == 'client';
    final isFundiCounter = isCountered && counterBy == 'fundi';
    final isAcceptedCounter =
        status == 'counter_accepted_by_fundi' ||
        status == 'counter_accepted' ||
        status == 'counter_accepted_by_fundi_pending';
    final myCounterAmt =
        ((widget.bid.bid['clientCounterAmount'] ??
                    widget.bid.bid['lastCounterAmount'] ??
                    0)
                as num)
            .toInt();
    final fundiCounterAmt =
        ((widget.bid.bid['fundiCounterAmount'] ??
                    widget.bid.bid['lastCounterAmount'] ??
                    0)
                as num)
            .toInt();
    final acceptedAmt =
        ((widget.bid.bid['agreedPrice'] ??
                    widget.bid.bid['clientCounterAmount'] ??
                    myCounterAmt)
                as num)
            .toInt();
    final fundiName = (widget.bid.bid['fundiName'] ?? 'Fundi').toString();
    final fundiId = (widget.bid.bid['fundiId'] ?? widget.bid.bidDoc.id)
        .toString();

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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Text(
                            fundiName,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          // FIXED DISTANCE - no glitch
                          StreamBuilder<DatabaseEvent>(
                            stream: _rtdb
                                .ref('live_locations/$fundiId')
                                .onValue,
                            builder: (_, liveSnap) {
                              if (liveSnap.hasData &&
                                  liveSnap.data!.snapshot.value != null) {
                                try {
                                  var live = Map<String, dynamic>.from(
                                    liveSnap.data!.snapshot.value as Map,
                                  );
                                  double fLat = (live['lat'] as num).toDouble();
                                  double fLng = (live['lng'] as num).toDouble();
                                  double? jLat, jLng;
                                  var jGeo =
                                      widget.jobData['geopoint'] ??
                                      widget.jobData['location'] ??
                                      widget.jobData['customerLocation'];
                                  if (jGeo is GeoPoint) {
                                    jLat = jGeo.latitude;
                                    jLng = jGeo.longitude;
                                  }
                                  jLat ??=
                                      (widget.jobData['customerLat'] ??
                                              widget.jobData['clientLat'] ??
                                              widget.jobData['lat'])
                                          ?.toDouble();
                                  jLng ??=
                                      (widget.jobData['customerLng'] ??
                                              widget.jobData['clientLng'] ??
                                              widget.jobData['lng'])
                                          ?.toDouble();
                                  if (jLat != null && jLng != null) {
                                    double km =
                                        Geolocator.distanceBetween(
                                          jLat,
                                          jLng,
                                          fLat,
                                          fLng,
                                        ) /
                                        1000;
                                    if (km > 0.05) _lastKm = km;
                                  }
                                } catch (_) {}
                              }
                              if (_lastKm == null)
                                return const SizedBox.shrink();
                              return Text(
                                '(${_lastKm!.toStringAsFixed(1)} km)',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              );
                            },
                          ),
                          if (widget.bid.verified)
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.blue,
                            ),
                          if (isAcceptedCounter)
                            Container(
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
                            '${widget.bid.rating.toStringAsFixed(1)}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.bid.referrals} referrals • ${widget.bid.jobsDone} jobs',
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
                  level: widget.bid.level,
                  isVerified: widget.bid.verified,
                  referralCount: widget.bid.referrals,
                  jobsDone: widget.bid.jobsDone,
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
                  'KES ${widget.bid.bid['price'] ?? widget.bid.bid['amount'] ?? widget.bid.bid['bidAmount'] ?? 0}',
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
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.greenSuccess,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: openConfirm,
                          child: Text(
                            'PROCEED WITH ${fundiName.toUpperCase()}',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: cancelAccepted,
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
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
