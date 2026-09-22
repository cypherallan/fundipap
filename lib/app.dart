import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth/role_select_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/customer/home/customer_home.dart';
import 'screens/customer/home/customer_notifications_page.dart';
import 'screens/customer/my_jobs/post_job_screen.dart';
import 'screens/customer/disputes_screen.dart';
import 'screens/fundi/home/fundi_home.dart';
import 'screens/fundi/home/fundi_notifications_page.dart';
import 'screens/fundi/disputes_screen.dart' as fundi_disputes;
import 'screens/admin/admin_screen.dart';
import 'services/auth_service.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/fundi/fundi_profile.dart';
import 'screens/fundi/my_jobs/fundi_my_jobs_page.dart';

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
            if (value == 'profile')
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfileScreen(email: widget.email, role: widget.role),
                ),
              );
            else if (value == 'settings')
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${widget.role} Settings coming soon')),
              );
            else if (value == 'logout') {
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
        const FundiHome(),
        const FundiNotificationsPage(),
        const FundiMyJobsPage(),
        const FundiProfile(),
        const fundi_disputes.FundiDisputesScreen(),
      ];
      return Scaffold(
        appBar: _buildAppBar(),
        body: fundiPages[_index.clamp(0, 4)],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index.clamp(0, 4),
          backgroundColor: Colors.white,
          indicatorColor: FundipapColors.primaryYellow,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: FundiNotifBadgeIcon(isSelected: _index == 1),
              label: 'Notifications',
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
    if (widget.role == 'admin')
      return Scaffold(appBar: _buildAppBar(), body: const AdminScreen());
    final pages = [
      const CustomerHome(),
      const CustomerNotificationsPage(),
      const PostJobScreen(),
      const DisputesScreen(),
      ProfileScreen(email: widget.email, role: widget.role),
    ];
    return Scaffold(
      appBar: _buildAppBar(),
      body: pages[_index.clamp(0, 4)],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, 4),
        backgroundColor: Colors.white,
        indicatorColor: FundipapColors.primaryYellow,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: ClientNotifBadgeIcon(isSelected: _index == 1),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Job Status',
          ),
          const NavigationDestination(
            icon: Icon(Icons.report_problem_outlined),
            selectedIcon: Icon(Icons.report_problem),
            label: 'Disputes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// CLIENT BADGE
class ClientNotifBadgeIcon extends StatefulWidget {
  final bool isSelected;
  const ClientNotifBadgeIcon({super.key, required this.isSelected});
  @override
  State<ClientNotifBadgeIcon> createState() => _ClientNotifBadgeIconState();
}

class _ClientNotifBadgeIconState extends State<ClientNotifBadgeIcon> {
  int _count = 0;
  StreamSubscription? _jobsSub;
  StreamSubscription? _activeSub;
  StreamSubscription? _escrowSub;
  final Map<String, StreamSubscription> _bidsSubs = {};
  final Map<String, int> _bidsPerJob = {};
  int _activeCount = 0;
  int _escrowCount = 0;

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['open', 'bidding'])
        .snapshots()
        .listen((jobsSnap) {
          for (var jobDoc in jobsSnap.docs) {
            var jobId = jobDoc.id;
            if (_bidsSubs.containsKey(jobId)) continue;
            _bidsSubs[jobId] = FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .collection('bids')
                .snapshots()
                .listen((bidsSnap) {
                  int c = 0;
                  for (var b in bidsSnap.docs) {
                    var d = b.data();
                    if (d['status'] == 'rejected' ||
                        d['status'] == 'accepted' ||
                        d['deletedForFundi'] == true)
                      continue;
                    c++;
                  }
                  _bidsPerJob[jobId] = c;
                  _recalc();
                });
          }
        });
    _escrowSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['assigned', 'confirmed'])
        .snapshots()
        .listen((snap) {
          int c = 0;
          for (var doc in snap.docs) {
            var esc = (doc.data()['escrowStatus'] ?? 'pending').toString();
            if (esc == 'pending') c++;
          }
          _escrowCount = c;
          _recalc();
        });
    _activeSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where(
          'status',
          whereIn: [
            'travelling',
            'site_visit',
            'in_progress',
            'pending_completion',
            'job_completed',
          ],
        )
        .snapshots()
        .listen((snap) {
          int active = 0;
          for (var doc in snap.docs) {
            var job = doc.data();
            var reneg = job['renegotiation'] as Map<String, dynamic>?;
            bool travelling =
                (job['travelling'] == true) ||
                (job['siteVisitStarted'] == true) ||
                (job['status'] == 'travelling');
            if (travelling && job['siteVisitDone'] != true)
              active++;
            else if (job['siteVisitDone'] == true &&
                job['status'] == 'site_visit' &&
                (reneg == null || reneg['requested'] != true))
              active++;
            else if (reneg != null &&
                reneg['requested'] == true &&
                reneg['status'] == 'pending')
              active++;
            else if (reneg != null &&
                reneg['currentPhase'] == 'parts_confirmed_by_fundi')
              active++;
            else if (reneg != null &&
                (reneg['currentPhase'] == 'fundi_working' ||
                    reneg['currentPhase'] == 'completed_by_fundi'))
              active++;
            else if (job['status'] == 'in_progress' ||
                job['status'] == 'pending_completion' ||
                job['status'] == 'job_completed')
              active++;
          }
          _activeCount = active;
          _recalc();
        });
  }

  void _recalc() {
    int bidsTotal = _bidsPerJob.values.fold(0, (a, b) => a + b);
    if (mounted)
      setState(() => _count = bidsTotal + _activeCount + _escrowCount);
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _activeSub?.cancel();
    _escrowSub?.cancel();
    for (var s in _bidsSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData ic = widget.isSelected
        ? Icons.notifications
        : Icons.notifications_outlined;
    if (_count <= 0) return Icon(ic);
    return Badge(label: Text('$_count'), child: Icon(ic));
  }
}

// FUNDI BADGE - THIS WAS MISSING
class FundiNotifBadgeIcon extends StatefulWidget {
  final bool isSelected;
  const FundiNotifBadgeIcon({super.key, required this.isSelected});
  @override
  State<FundiNotifBadgeIcon> createState() => _FundiNotifBadgeIconState();
}

class _FundiNotifBadgeIconState extends State<FundiNotifBadgeIcon> {
  int _count = 0;
  StreamSubscription? _bidsSub;
  StreamSubscription? _jobsSub;
  int _bidsAccepted = 0;
  int _jobsCountered = 0;
  int _escrowPaid = 0;

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    _bidsSub = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
          int c = 0;
          for (var doc in snap.docs) {
            var b = doc.data();
            if (b['status'] == 'accepted') c++;
          }
          _bidsAccepted = c;
          _recalc();
        });
    _jobsSub = FirebaseFirestore.instance.collection('jobs').snapshots().listen(
      (snap) {
        int countered = 0;
        int escrow = 0;
        for (var doc in snap.docs) {
          var job = doc.data();
          bool isMine =
              job['assignedFundiId'] == uid ||
              job['assignedFundi'] == uid ||
              job['fundiId'] == uid ||
              job['acceptedFundiId'] == uid;
          if (!isMine) continue;
          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          var escrowStatus = (job['escrowStatus'] ?? 'pending').toString();
          var status = (job['status'] ?? '').toString();
          if ((escrowStatus == 'paid' || escrowStatus == 'held') &&
              (status == 'assigned' || status == 'confirmed'))
            escrow++;
          if (reneg != null &&
              (reneg['status'] == 'countered_by_client' ||
                  reneg['status'] == 'accepted_client_buys_parts' ||
                  reneg['status'] == 'accepted_fundi_buys_at_client_risk'))
            countered++;
        }
        _jobsCountered = countered;
        _escrowPaid = escrow;
        _recalc();
      },
    );
  }

  void _recalc() {
    if (mounted)
      setState(() => _count = _bidsAccepted + _jobsCountered + _escrowPaid);
  }

  @override
  void dispose() {
    _bidsSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData ic = widget.isSelected
        ? Icons.notifications
        : Icons.notifications_outlined;
    if (_count <= 0) return Icon(ic);
    return Badge(label: Text('$_count'), child: Icon(ic));
  }
}
