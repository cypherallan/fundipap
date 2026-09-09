import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const FundipapApp());
}

// --- FUNDIPAP DESIGN SYSTEM v1.0 LOCKED ---
class FundipapColors {
  static const primaryYellow = Color(0xFFFFC107);
  static const blackGray = Color(0xFF121212);
  static const greenSuccess = Color(0xFF4CAF50);
  static const redAlert = Color(0xFFF44336);
  static const bgLight = Color(0xFFFBF8F0);
}

class FundipapApp extends StatelessWidget {
  const FundipapApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      scaffoldBackgroundColor: FundipapColors.bgLight,
      colorScheme: const ColorScheme.light(
        primary: FundipapColors.primaryYellow,
        secondary: FundipapColors.blackGray,
        error: FundipapColors.redAlert,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'FUNDI PAP - Ogango Kisumu',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
          displayLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: FundipapColors.blackGray,
          ),
          titleLarge: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: FundipapColors.blackGray,
          ),
          titleMedium: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: FundipapColors.blackGray,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FundipapColors.blackGray,
            foregroundColor: FundipapColors.primaryYellow,
            textStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeNavigator(),
    );
  }
}

class HomeNavigator extends StatefulWidget {
  const HomeNavigator({super.key});
  @override
  State<HomeNavigator> createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends State<HomeNavigator> {
  int _index = 0;
  final screens = const [
    CustomerOfferScreen(),
    FundiCounterScreen(),
    FraudPreventionScreen(),
    AdminFraudMonitorScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: FundipapColors.primaryYellow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Customer',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            label: 'Fundi',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            label: 'Fraud Block',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: 'Admin',
          ),
        ],
      ),
    );
  }
}

class CustomerOfferScreen extends StatelessWidget {
  const CustomerOfferScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FUNDI PAP',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: FundipapColors.primaryYellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'OGANGO • KISUMU',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Fundi: Otieno Wireman',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
            Text(
              'Electrical - Wiring fix in Nyalenda',
              style: GoogleFonts.inter(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fundi Service Fee', style: GoogleFonts.inter()),
                      Text(
                        'KES 1,200',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Platform Fee (Customer pays)',
                        style: GoogleFonts.inter(),
                      ),
                      Text(
                        'KES 120',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL YOU PAY',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'KES 1,320',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Money held in escrow until job is done',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.verified,
                    color: FundipapColors.greenSuccess,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'STK Push sent: Pay KES 1,320 with M-Pesa...',
                      ),
                    ),
                  );
                },
                child: const Text('Confirm & Pay — KES 1,320'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FundiCounterScreen extends StatelessWidget {
  const FundiCounterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FundipapColors.blackGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Habari, Fundi',
                style: GoogleFonts.inter(color: Colors.white70),
              ),
              Text(
                'Your Earnings',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FundipapColors.primaryYellow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOU GET FULL',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'KES 1,200',
                      style: GoogleFonts.montserrat(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Platform fee paid by customer. No deduction from you.',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FraudPreventionScreen extends StatefulWidget {
  const FraudPreventionScreen({super.key});
  @override
  State<FraudPreventionScreen> createState() => _FraudPreventionScreenState();
}

class _FraudPreventionScreenState extends State<FraudPreventionScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerified = false;
  static const String _correctOtp = '4829';
  void _verify() {
    if (_otpController.text == _correctOtp) {
      setState(() => _isVerified = true);
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
                color: _isVerified
                    ? FundipapColors.greenSuccess.withOpacity(0.15)
                    : FundipapColors.redAlert.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isVerified
                      ? FundipapColors.greenSuccess
                      : FundipapColors.redAlert,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isVerified ? Icons.verified_user : Icons.shield,
                    color: _isVerified
                        ? FundipapColors.greenSuccess
                        : FundipapColors.redAlert,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isVerified
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
            if (!_isVerified) ...[
              Text(
                'Enter OTP to confirm you received old part',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _otpController,
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

class AdminFraudMonitorScreen extends StatelessWidget {
  const AdminFraudMonitorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final fundis = [
      {'name': 'Otieno Wireman', 'partsRate': 85, 'extraAvg': 650},
      {'name': 'Akinyi Plumber', 'partsRate': 25, 'extraAvg': 120},
      {'name': 'Omondi Painter', 'partsRate': 45, 'extraAvg': 300},
      {'name': 'Atieno Mason', 'partsRate': 75, 'extraAvg': 800},
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Fraud Monitor',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ogango Kisumu Fundis',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children:
                    [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: FundipapColors.blackGray,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'FUNDI',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'PARTS REQ RATE',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'EXTRA AVG',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'STATUS',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]..addAll(
                      fundis.map((f) {
                        int rate = f['partsRate'] as int;
                        Color statusColor = rate > 70
                            ? FundipapColors.redAlert
                            : (rate < 30
                                  ? FundipapColors.greenSuccess
                                  : FundipapColors.primaryYellow);
                        String statusText = rate > 70
                            ? 'RED >70%'
                            : (rate < 30 ? 'GREEN <30%' : 'YELLOW');
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.black12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  f['name'] as String,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$rate%',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'KES ${f['extraAvg']}',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
