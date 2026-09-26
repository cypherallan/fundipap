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

  double distanceKm = 0;
  int transportFee = 100; // START AT 100 NOT 0
  String transportMode = 'boda';
  int labor = 0;
  int clientAppFee = 0;
  int fundiAppFee = 0;
  int totalClientPays = 0;
  int fundiReceives = 0;
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
      double km = t['km'] as double;

      // YOUR RULE: min 100 if <=1km, never <100
      if (trans < 100) trans = 100;
      if (km <= 1.0 && trans < 100) trans = 100;

      int cFee = (lab * 0.05).round();
      int fFee = (lab * 0.05).round();
      setState(() {
        distanceKm = km;
        transportFee = trans; // always >=100
        transportMode = t['mode'] as String;
        labor = lab;
        clientAppFee = cFee;
        fundiAppFee = fFee;
        totalClientPays = lab + trans + cFee; // 5000+100+250=5350
        fundiReceives = lab - fFee + trans;
        transportLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          // fallback to min rule even on error
          if (transportFee < 100) transportFee = 100;
          if (labor > 0) {
            clientAppFee = (labor * 0.05).round();
            fundiAppFee = (labor * 0.05).round();
            totalClientPays = labor + transportFee + clientAppFee;
            fundiReceives = labor - fundiAppFee + transportFee;
          }
          transportLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    var combined = {...?user, ...?fundi, ...widget.bidData};
    int effectiveTransport = transportFee < 100 ? 100 : transportFee;

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
        bidData: {
          ...widget.bidData,
          'transportFee': effectiveTransport,
          'distanceKm': distanceKm,
        },
        labor: labor,
        transportFee: effectiveTransport,
        appFee: clientAppFee,
        total: totalClientPays > 0
            ? totalClientPays
            : labor + effectiveTransport + clientAppFee,
        distanceKm: distanceKm,
        transportMode: transportMode,
        onReject: rejectFundi,
        onConfirm: () => confirmFundi(
          totalToLock: totalClientPays,
          clientAppFee: clientAppFee,
          fundiAppFee: fundiAppFee,
          fundiReceives: fundiReceives,
          transportFee: effectiveTransport,
          labor: labor,
        ),
        onReport: reportFraud,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ConfirmFundiProfileCard(combined: combined),
            const SizedBox(height: 12),
            ConfirmFundiDetailsSection(combined: combined),
            const SizedBox(height: 12),
            ConfirmFundiBidCard(
              jobData: widget.jobData,
              bidData: {
                ...widget.bidData,
                'transportFee': effectiveTransport,
                'distanceKm': distanceKm,
              },
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
