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
    return PopScope(
      canPop: false, // MANDATORY - can't go back, same as RateFundiScreen
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
                'KES ${widget.amount} Released!',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'KES ${widget.amount} has been successfully released to your account by ${widget.clientName}. Kindly confirm your account balance / M-Pesa before rating.',
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
                              'YES, RECEIVED KES ${widget.amount}',
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
