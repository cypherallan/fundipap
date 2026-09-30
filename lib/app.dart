import 'dart:async';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/customer/home/customer_home.dart';
import 'screens/customer/my_jobs/post_job_screen.dart';
import 'screens/customer/disputes_screen.dart';
import 'screens/fundi/home/fundi_home.dart';
import 'screens/fundi/fundi_disputes_screen.dart' as fundi_disputes;
import 'services/auth_service.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/fundi/fundi_profile.dart';
import 'screens/fundi/my_jobs/fundi_my_jobs_page.dart';
import 'screens/admin/admin_screen.dart';

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
  final int initialIndex;
  final int initialJobStatusTab;
  const HomeNavigator({
    super.key,
    this.role = 'client',
    this.email = '',
    this.initialIndex = 0,
    this.initialJobStatusTab = 0,
  });
  @override
  State<HomeNavigator> createState() => _HomeNavigatorState();
}

class _HomeNavigatorState extends State<HomeNavigator> {
  late int _index;
  int _refreshId = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  Future<void> _handleRefresh() async {
    setState(() => _refreshId++);
    await Future.delayed(const Duration(milliseconds: 700));
  }

  AppBar _buildAppBar() {
    bool isFundi = widget.role == 'fundi';
    return AppBar(
      backgroundColor: isFundi ? FundipapColors.blackGray : Colors.white,
      foregroundColor: isFundi ? Colors.white : Colors.black,
      leading: null,
      title: Text('FUNDI PAP - ${widget.role.toUpperCase()}'),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'profile') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileScreen(email: widget.email, role: widget.role),
                ),
              );
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
      final fundiPages = [
        FundiHome(key: ValueKey('fh_$_refreshId')),
        FundiMyJobsPage(key: ValueKey('fmj_$_refreshId')),
        FundiProfile(key: ValueKey('fp_$_refreshId')),
        fundi_disputes.FundiDisputesScreen(key: ValueKey('fd_$_refreshId')),
      ];
      return Scaffold(
        appBar: _buildAppBar(),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: FundipapColors.primaryYellow,
          child: fundiPages[_index.clamp(0, 3)],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index.clamp(0, 3),
          backgroundColor: Colors.white,
          indicatorColor: FundipapColors.primaryYellow,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'My Jobs',
            ),
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'My Advert',
            ),
            const NavigationDestination(
              icon: Icon(Icons.report_problem_outlined),
              selectedIcon: Icon(Icons.report_problem),
              label: 'Disputes',
            ),
          ],
        ),
      );
    }
    if (widget.role == 'admin') {
      return Scaffold(appBar: _buildAppBar(), body: const AdminScreen());
    }

    // CLIENT NOW HAS 4 TABS ONLY - Notifications removed (now on Home)
    final pages = [
      CustomerHome(key: ValueKey('ch_$_refreshId')),
      PostJobScreen(
        key: ValueKey('cp_$_refreshId'),
        initialTabIndex: widget.initialJobStatusTab,
      ),
      DisputesScreen(key: ValueKey('cd_$_refreshId')),
      ProfileScreen(
        email: widget.email,
        role: widget.role,
        key: ValueKey('cpr_$_refreshId'),
      ),
    ];
    return Scaffold(
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: FundipapColors.primaryYellow,
        child: pages[_index.clamp(0, 3)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, 3),
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
            label: 'Job Status',
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
