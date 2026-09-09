import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/customer/customer_home.dart';
import 'screens/fundi/fundi_home.dart';
import 'screens/escrow/escrow_screen.dart';
import 'screens/admin/admin_screen.dart';

class FundiPapApp extends StatelessWidget {
  const FundiPapApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fundi Pap - Kisumu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
    CustomerHome(),
    FundiHome(),
    EscrowScreen(),
    AdminScreen(),
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
