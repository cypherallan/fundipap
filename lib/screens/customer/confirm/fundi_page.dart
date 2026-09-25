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

  // TRANSPORT + FEE STATE
  double distanceKm = 0;
  int transportFee = 0;
  String transportMode = 'boda';
  int labor = 0;
  int clientAppFee = 0; // 5% client sees
  int fundiAppFee = 0; // 5% hidden, for DB
  int totalClientPays = 0; // 5350
  int fundiReceives = 0; // 4850
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
      int lab =
          ((widget.bidData['amount'] ??
                      widget.bidData['bidAmount'] ??
                      widget.bidData['price'] ??
                      0)
                  as num)
              .toInt();
      int trans = t['fee'] as int;
      int cFee = (lab * 0.05).round(); // client 5%
      int fFee = (lab * 0.05).round(); // fundi 5% - hidden here
      setState(() {
        distanceKm = t['km'] as double;
        transportFee = trans;
        transportMode = t['mode'] as String;
        labor = lab;
        clientAppFee = cFee;
        fundiAppFee = fFee;
        totalClientPays = lab + trans + cFee; // 5000+100+250=5350
        fundiReceives = lab - fFee + trans; // 4850 - for DB only
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
        total: totalClientPays, // BUTTON SHOWS ONLY TOTAL 5350
        distanceKm: distanceKm,
        transportMode: transportMode,
        onReject: rejectFundi,
        onConfirm: () => confirmFundi(
          totalToLock: totalClientPays,
          clientAppFee: clientAppFee,
          fundiAppFee: fundiAppFee,
          fundiReceives: fundiReceives,
          transportFee: transportFee,
          labor: labor,
        ),
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
            // RECEIPT CARD - CLIENT SEES THIS
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                            'Calculating...',
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
                                'Fundi is ${distanceKm < 1 ? '${(distanceKm * 1000).toStringAsFixed(0)}m' : '${distanceKm.toStringAsFixed(1)}km'} away',
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
                                  color: Colors.blue.shade50,
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
                          SizedBox(height: 12),
                          _receiptRow('Fundi labour charges:', 'KES $labor'),
                          SizedBox(height: 6),
                          _receiptRow('Transport cost:', 'KES $transportFee'),
                          SizedBox(height: 6),
                          _receiptRow(
                            'App maintenance cost:',
                            'KES $clientAppFee',
                          ),
                          Divider(height: 20),
                          _receiptRow(
                            'Total to pay:',
                            'KES $totalClientPays',
                            isBold: true,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'This amount will be locked and paid after job completion',
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

  Widget _receiptRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
