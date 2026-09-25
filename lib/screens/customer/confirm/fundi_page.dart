import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/transport_calculator.dart';
import 'fundi_actions.dart';
import 'fundi_profile_card.dart';
import 'fundi_details_section.dart';
import 'fundi_bid_card.dart';
import 'fundi_reviews.dart';
import 'fundi_bottom_actions.dart';

class ConfirmFundiPage extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;
  final String bidId;
  final Map<String, dynamic> bidData;
  const ConfirmFundiPage({
    super.key,
    required this.jobId,
    required this.jobData,
    required this.bidId,
    required this.bidData,
  });
  @override
  State<ConfirmFundiPage> createState() => _ConfirmFundiPageState();
}

class _ConfirmFundiPageState extends State<ConfirmFundiPage>
    with ConfirmFundiActionsMixin {
  @override
  Map<String, dynamic>? fundi;
  @override
  Map<String, dynamic>? user;
  @override
  bool loading = true;

  // TRANSPORT STATE - for Review display
  double distanceKm = 0;
  int transportFee = 0;
  String transportMode = 'boda';
  int labor = 0;
  int total = 0;
  bool transportLoading = true;

  @override
  String get jobId => widget.jobId;
  @override
  Map<String, dynamic> get jobData => widget.jobData;
  @override
  String get bidId => widget.bidId;
  @override
  Map<String, dynamic> get bidData => widget.bidData;

  @override
  void initState() {
    super.initState();
    loadFundi().then((_) => _loadTransport());
  }

  Future<void> _loadTransport() async {
    try {
      var t = await TransportCalculator.calc(
        jobData: widget.jobData,
        fundiId: widget.bidData['fundiId'],
      );
      if (!mounted) return;
      setState(() {
        distanceKm = t['km'] as double;
        transportFee = t['fee'] as int;
        transportMode = t['mode'] as String;
        labor =
            (widget.bidData['amount'] ??
                    widget.bidData['bidAmount'] ??
                    widget.bidData['price'] ??
                    0)
                .toInt();
        total = labor + transportFee;
        transportLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => transportLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    var combined = {...?user, ...?fundi, ...widget.bidData};

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          'Review Fundi',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: FundipapColors.redAlert),
            onPressed: reportFraud,
            tooltip: 'Report Fraud',
          ),
        ],
      ),
      bottomNavigationBar: ConfirmFundiBottomActions(
        bidData: widget.bidData,
        labor: labor,
        transportFee: transportFee,
        total: total,
        distanceKm: distanceKm,
        transportMode: transportMode,
        onReject: rejectFundi,
        onConfirm: confirmFundi,
        onReport: reportFraud,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConfirmFundiProfileCard(combined: combined),
            const SizedBox(height: 12),
            ConfirmFundiDetailsSection(combined: combined),
            const SizedBox(height: 12),
            // NEW: Distance + Total to be locked
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: transportLoading
                    ? Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Calculating distance...',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Fundi is ${distanceKm.toStringAsFixed(1)} km away',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  transportMode,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Labor: KES $labor',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          Text(
                            'Transport ($transportMode): KES $transportFee',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          Divider(),
                          Text(
                            'TOTAL TO LOCK IN ESCROW: KES $total',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'This whole amount will be locked to escrow',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            ConfirmFundiBidCard(
              jobData: widget.jobData,
              bidData: widget.bidData,
            ),
            const SizedBox(height: 16),
            ConfirmFundiReviews(fundiId: widget.bidData['fundiId']),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
