import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/customer/customer_home.dart';
import 'screens/fundi/fundi_home.dart';
import 'screens/admin/admin_screen.dart';

class FundiPapApp extends StatelessWidget {
  const FundiPapApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fundi Pap - Kisumu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const RoleSelectScreen(),
    );
  }
}

class HomeNavigator extends StatefulWidget {
  final String role;
  final String email;
  const HomeNavigator({super.key, this.role = 'client', this.email = ''});
  @override
  State<HomeNavigator> createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends State<HomeNavigator> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    // ROLE BASED SCREENS
    if (widget.role == 'fundi') {
      return Scaffold(
        body: const FundiHome(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
            BottomNavigationBarItem(
              icon: Icon(Icons.wallet),
              label: 'Earnings',
            ),
          ],
        ),
      );
    }
    if (widget.role == 'admin') {
      return const Scaffold(body: AdminScreen()); // ONLY admin features
    }
    // DEFAULT: CLIENT
    return Scaffold(
      body: const CustomerHome(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: FundipapColors.primaryYellow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt), label: 'My Jobs'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
