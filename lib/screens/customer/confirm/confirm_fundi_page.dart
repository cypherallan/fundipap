import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import 'confirm_fundi_actions.dart';
import 'confirm_fundi_profile_card.dart';
import 'confirm_fundi_details_section.dart';
import 'confirm_fundi_bid_card.dart';
import 'confirm_fundi_reviews.dart';
import 'confirm_fundi_bottom_actions.dart';

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
    loadFundi();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
