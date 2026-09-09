import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/customer/customer_home.dart';
import 'screens/customer/post_job_screen.dart';
import 'screens/customer/disputes_screen.dart';
import 'screens/fundi/fundi_home.dart';
import 'screens/admin/admin_screen.dart';
import 'services/auth_service.dart';
import 'screens/profile/profile_screen.dart';

class FundiPapApp extends StatelessWidget {
  const FundiPapApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fundi Pap - Kisumu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
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

  AppBar _buildAppBar() {
    bool isFundi = widget.role == 'fundi';
    return AppBar(
      backgroundColor: isFundi ? FundipapColors.blackGray : Colors.white,
      foregroundColor: isFundi ? Colors.white : Colors.black,
      title: Text('FUNDI PAP - ${widget.role.toUpperCase()}'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'profile') {
              setState(() => _index = 3); // Profile is last now
            } else if (value == 'settings') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.role} Settings coming soon')),
              );
            } else if (value == 'logout') {
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                (r) => false,
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text('Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'fundi') {
      return Scaffold(
        appBar: _buildAppBar(),
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
      return Scaffold(appBar: _buildAppBar(), body: const AdminScreen());
    }
    // CLIENT - NEW 4 TABS: Home, Post Job, Disputes, Profile
    final pages = [
      const CustomerHome(), // Home dashboard
      const PostJobScreen(), // Post Job + pending + completed inside
      const DisputesScreen(),
      ProfileScreen(email: widget.email, role: widget.role),
    ];
    return Scaffold(
      appBar: _buildAppBar(),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: FundipapColors.primaryYellow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Post Job',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_problem_outlined),
            selectedIcon: Icon(Icons.report_problem),
            label: 'Disputes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
