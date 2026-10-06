import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/transport_calculator.dart';
import '../actions/confirm_fundi_actions.dart';
import '../profile/confirm_fundi_profile_card.dart';
import '../profile/confirm_fundi_details_section.dart';
import '../bidding/confirm_fundi_bid_card.dart';
import '../profile/confirm_fundi_reviews.dart';

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
  int transportFee = 100;
  String transportMode = 'boda';
  int labor = 0;
  int clientAppFee = 0;
  int fundiAppFee = 0;
  int totalClientPays = 0;
  int fundiReceives = 0;
  bool transportLoading = true;
  bool counterLoading = false;

  bool get isAcceptedCounter {
    final s = (widget.bidData['status'] ?? '').toString();
    return s.contains('counter_accepted_by_fundi') || s == 'counter_accepted';
  }

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

  int _getEffectiveLabor() {
    // FIX: new countered offer calculations - use agreedPrice / client counter first
    final b = widget.bidData;
    return ((b['agreedPrice'] ??
                b['clientCounterAmount'] ??
                b['lastCounterAmount'] ??
                b['clientCounterPrice'] ??
                b['amount'] ??
                b['bidAmount'] ??
                b['price'] ??
                0)
            as num)
        .toInt();
  }

  Future<void> _loadTransport() async {
    try {
      var t = await TransportCalculator.calc(
        jobData: widget.jobData,
        fundiId: widget.bidData['fundiId'],
      );
      if (!mounted) return;
      int lab = _getEffectiveLabor();
      int trans = t['fee'] as int;
      double km = t['km'] as double;
      if (trans < 100) trans = 100;
      if (km <= 1.0 && trans < 100) trans = 100;
      int cFee = (lab * 0.05).round();
      int fFee = (lab * 0.05).round();
      setState(() {
        distanceKm = km;
        transportFee = trans;
        transportMode = t['mode'] as String;
        labor = lab;
        clientAppFee = cFee;
        fundiAppFee = fFee;
        totalClientPays = lab + trans + cFee; // 5000 + 100 + 250 = 5350
        fundiReceives = lab - fFee + trans;
        transportLoading = false;
      });
    } catch (_) {
      if (mounted) {
        int lab = _getEffectiveLabor();
        setState(() {
          labor = lab;
          clientAppFee = (lab * 0.05).round();
          fundiAppFee = (lab * 0.05).round();
          totalClientPays = lab + transportFee + clientAppFee;
          fundiReceives = lab - fundiAppFee + transportFee;
          transportLoading = false;
        });
      }
    }
  }

  Future<void> _showCounterDialog() async {
    final ctrl = TextEditingController(text: labor > 0 ? labor.toString() : '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Counter Offer',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Your offer (KES)',
            prefixText: 'KES ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amt = int.tryParse(ctrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              Navigator.pop(ctx);
              await _sendCounter(amt);
            },
            child: const Text('Send Counter'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCounter(int amount) async {
    setState(() => counterLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final fundiId = widget.bidData['fundiId'];
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .collection('bids')
          .doc(widget.bidId)
          .update({
            'clientCounterAmount': amount,
            'clientCounterPrice': amount,
            'lastCounterAmount': amount,
            'lastCounterPrice': amount,
            'counterPrice': amount,
            'lastCounterBy': 'client',
            'counterBy': 'client',
            'counterById': uid,
            'counterAt': FieldValue.serverTimestamp(),
            'lastCounterAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'status': 'countered',
            'clientCounterSeenByFundi': false,
            'fundiHasUnread': true,
          });
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'lastCounterAmount': amount,
            'lastCounterPrice': amount,
            'lastCounterBy': 'client',
            'counterBy': 'client',
            'status': 'countered',
            'updatedAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': true,
            'clientActionAt': FieldValue.serverTimestamp(),
          });
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': fundiId,
        'toRole': 'fundi',
        'fromUserId': uid,
        'fromRole': 'client',
        'type': 'counter_offer',
        'jobId': widget.jobId,
        'bidId': widget.bidId,
        'amount': amount,
        'title': 'Counter offer received',
        'body':
            'Client countered your KES ${widget.bidData['price']} bid with KES $amount',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('fundis')
          .doc(fundiId)
          .collection('notifications')
          .add({
            'jobId': widget.jobId,
            'bidId': widget.bidId,
            'type': 'counter',
            'amount': amount,
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Counter KES $amount sent to fundi')),
      );
      Navigator.pop(context, false);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => counterLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    var combined = {...?user, ...?fundi, ...widget.bidData};
    int effectiveTransport = transportFee < 100 ? 100 : transportFee;
    int totalToShow = totalClientPays > 0
        ? totalClientPays
        : labor + effectiveTransport + clientAppFee;

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
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!transportLoading)
                Column(
                  children: [
                    if (isAcceptedCounter)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Fundi accepted your counter KES $labor',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Labor',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          'KES $labor',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transport ($transportMode ${distanceKm.toStringAsFixed(1)}km)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          'KES $effectiveTransport',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'App Maintenance (5%)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          'KES $clientAppFee',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAcceptedCounter
                              ? 'You pay (accepted counter)'
                              : 'Total you pay',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'KES $totalToShow',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: counterLoading ? null : rejectFundi,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Reject',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isAcceptedCounter)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: counterLoading ? null : _showCounterDialog,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: counterLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Counter',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  if (!isAcceptedCounter) const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.blackGray,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => confirmFundi(
                        totalToLock: totalClientPays,
                        clientAppFee: clientAppFee,
                        fundiAppFee: fundiAppFee,
                        fundiReceives: fundiReceives,
                        transportFee: effectiveTransport,
                        labor: labor,
                      ),
                      child: Text(
                        'Confirm • KES $totalToShow',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                'agreedPrice': labor,
                'clientCounterAmount': labor,
                'effectiveLabor': labor,
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
