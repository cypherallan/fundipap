import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class EscrowScreen extends StatefulWidget {
  const EscrowScreen({super.key});
  @override
  State<EscrowScreen> createState() => _EscrowScreenState();
}

class _EscrowScreenState extends State<EscrowScreen> {
  final TextEditingController _otp = TextEditingController();
  bool _verified = false;
  static const String _correctOtp = '4829';
  void _verify() {
    if (_otp.text == _correctOtp) {
      setState(() => _verified = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: FundipapColors.redAlert,
          content: Text('Wrong OTP. Old part not confirmed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fraud Prevention',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _verified
                    ? FundipapColors.greenSuccess.withOpacity(0.15)
                    : FundipapColors.redAlert.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _verified
                      ? FundipapColors.greenSuccess
                      : FundipapColors.redAlert,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _verified ? Icons.verified_user : Icons.shield,
                    color: _verified
                        ? FundipapColors.greenSuccess
                        : FundipapColors.redAlert,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _verified
                        ? 'Old Part Confirmed'
                        : 'Fraud Prevention Enabled',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Customer confirmation required - 4-Digit OTP 4829 - Extra payment will only be released after customer confirms old part receipt',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (!_verified) ...[
              Text(
                'Enter OTP to confirm you received old part',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '4829',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verify,
                  child: const Text('Confirm Old Part Receipt'),
                ),
              ),
            ] else ...[
              const Icon(
                Icons.check_circle,
                color: FundipapColors.greenSuccess,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                'Extra payment can now be released. Escrow unlocked.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
