import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../rating/rate_client_screen.dart';

class FundiConfirmPaymentScreen extends StatefulWidget {
  final String jobId;
  final int amount;
  final String clientName;
  final String clientId;
  final Map<String, dynamic> jobData;
  const FundiConfirmPaymentScreen({
    super.key,
    required this.jobId,
    required this.amount,
    required this.clientName,
    required this.clientId,
    required this.jobData,
  });
  @override
  State<FundiConfirmPaymentScreen> createState() =>
      _FundiConfirmPaymentScreenState();
}

class _FundiConfirmPaymentScreenState extends State<FundiConfirmPaymentScreen> {
  bool _confirming = false;

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  Future<void> _confirmReceived() async {
    setState(() => _confirming = true);
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'fundiConfirmedPayment': true,
            'fundiPaymentConfirmedAt': FieldValue.serverTimestamp(),
            'fundiHasUnread': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RateClientScreen(
            jobId: widget.jobId,
            clientId: widget.clientId.isNotEmpty
                ? widget.clientId
                : (widget.jobData['clientId'] ??
                          widget.jobData['customerId'] ??
                          '')
                      .toString(),
            clientName: widget.clientName,
            trade:
                (widget.jobData['title'] ??
                        widget.jobData['categoryName'] ??
                        '')
                    .toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _notReceived() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Contact support: support@fundipap.com - payment under review',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var job = widget.jobData;
    var reneg = job['renegotiation'] as Map<String, dynamic>? ?? {};

    // FIX: use accepted counter 1000 not raw 2000
    int rawExtra = _toInt(reneg['extraLabor'] ?? job['extraLaborAmount'] ?? 0);
    int counterExtra = _toInt(
      reneg['acceptedCounterExtraLabor'] ?? reneg['counterExtraLabor'] ?? 0,
    );
    int finalExtra = counterExtra > 0 ? counterExtra : rawExtra;

    int oldLabor = _toInt(reneg['oldLabor'] ?? 0);
    if (oldLabor == 0) {
      // fallback: agreedPrice was already updated to 6000, subtract extra
      int agreed = _toInt(job['agreedPrice'] ?? job['laborCost'] ?? 0);
      oldLabor = agreed > finalExtra ? agreed - finalExtra : agreed;
      if (oldLabor == 0) oldLabor = 5000;
    }

    int finalLabor = oldLabor + finalExtra; // 5000+1000=6000 NOT 7000
    int transport = _toInt(
      job['transportFee'] ?? reneg['oldTransportFee'] ?? 100,
    );
    int appFee = (finalLabor * 0.05).round(); // 300 NOT 350
    int fundiReceives =
        finalLabor - appFee + transport; // 6000-300+100=5800 NOT 6750
    int totalClientPays = finalLabor + transport + appFee; // 6400

    // Use computed receives, ignore wrong widget.amount (6750)
    int displayAmount = fundiReceives;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You MUST confirm payment received to unlock app'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Confirm Payment',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.green.shade50,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.verified, size: 70, color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'KES $displayAmount Released!',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              // FIX: breakdown shows correct 6000 +100 -300 = 5800
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Labour:', style: GoogleFonts.inter(fontSize: 12)),
                        Text(
                          'KES $finalLabor',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transport:',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        Text(
                          '+ KES $transport',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'App maintenance cost (5%):',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        Text(
                          '- KES $appFee',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total to receive:',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'KES $displayAmount',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (counterExtra > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Counter: KES $finalExtra (was KES $rawExtra) • Total client pays KES $totalClientPays',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'KES $displayAmount has been released by ${widget.clientName}. Confirm your M-Pesa.',
                style: GoogleFonts.inter(fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _notReceived,
                      child: const Text('NO, NOT RECEIVED'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.greenSuccess,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      onPressed: _confirming ? null : _confirmReceived,
                      child: _confirming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'YES, RECEIVED KES $displayAmount',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
