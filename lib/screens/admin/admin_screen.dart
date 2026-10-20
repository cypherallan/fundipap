import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../auth/role_select_screen.dart';
import 'tabs/categories_tab.dart';
import 'tabs/fraud_review_tab.dart';
import 'tabs/disputes_tab.dart';
import 'tabs/revenue_analytics_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _current = 0;
  final _pages = const [
    CategoriesTab(),
    RevenueAnalyticsTab(), // <-- NOW 2ND
    FraudReviewTab(),
    DisputesTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Use 3 dots menu to Logout')));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'FundiPap Admin - 24 Categories',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          backgroundColor: FundipapColors.blackGray,
          foregroundColor: Colors.white,
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'logout') {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted)
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => RoleSelectScreen()),
                      (r) => false,
                    );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _pages[_current],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.black12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _current,
            onTap: (i) => setState(() => _current = i),
            backgroundColor: Colors.white,
            selectedItemColor: FundipapColors.blackGray,
            unselectedItemColor: Colors.black54,
            selectedLabelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.category_outlined),
                activeIcon: Icon(Icons.category),
                label: 'Categories (24)',
              ),
              BottomNavigationBarItem(
                // <-- 2ND NOW
                icon: Icon(Icons.payments_outlined),
                activeIcon: Icon(Icons.payments),
                label: 'Revenue',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shield_outlined),
                activeIcon: Icon(Icons.shield),
                label: 'Fraud Review',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.gavel_outlined),
                activeIcon: Icon(Icons.gavel),
                label: 'Disputes',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
