import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';
import 'fundi_home_actions.dart';
import 'fundi_home_header_section.dart';
import 'fundi_home_jobs_tab.dart';
import 'fundi_home_completed_wrapper.dart';
import '../../chats/chat_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../notifications/notification_bell.dart';
import '../../../notifications/notification_service.dart';

class FundiHome extends StatefulWidget {
  const FundiHome({super.key});
  @override
  State<FundiHome> createState() => _FundiHomeState();
}

class _FundiHomeState extends State<FundiHome> with FundiHomeActionsMixin {
  @override
  String search = '';
  @override
  Map<String, dynamic>? me;
  @override
  int completedJobs = 0;
  @override
  double totalEarned = 0;
  @override
  int profilePct = 0;
  @override
  String mySkill = 'General';
  @override
  Position? currentPos;

  @override
  void initState() {
    super.initState();
    loadMe();
    WidgetsBinding.instance.addPostFrameCallback((_) => loadLocation(context));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 3,
      child: Container(
        color: FundipapColors.blackGray,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FundiHomeHeaderSection(
                    me: me,
                    profilePct: profilePct,
                    completedJobs: completedJobs,
                    totalEarned: totalEarned,
                    onReloadMe: loadMe,
                  ),
                ),
                NotificationBell(userId: uid, iconColor: Colors.white),
              ],
            ),
            // Banner for Client bought parts / Payment released
            StreamBuilder<QuerySnapshot>(
              stream: NotificationService.getUserNotificationsStream(uid),
              builder: (_, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty)
                  return const SizedBox.shrink();
                var unread = snap.data!.docs.where((d) {
                  var m = d.data() as Map<String, dynamic>;
                  return (m['isRead'] == false) &&
                      [
                        'parts_bought',
                        'payment_released',
                        'job_confirmed',
                        'escrow_held',
                      ].contains(m['type']);
                }).toList();
                if (unread.isEmpty) return const SizedBox.shrink();
                var data = unread.first.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 16,
                        color: Colors.blue.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? '',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              data['body'] ?? '',
                              style: GoogleFonts.inter(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () =>
                            NotificationService.markAsRead(unread.first.id),
                      ),
                    ],
                  ),
                );
              },
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab, // <- ADD THIS
                indicatorPadding: EdgeInsets.zero, // <- ADD THIS
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: FundipapColors.primaryYellow,
                  borderRadius: BorderRadius.circular(12),
                ),

                labelColor: Colors.black,
                unselectedLabelColor: Colors.white70,
                labelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                tabs: [
                  Tab(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white24, width: 1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Jobs Near You'),
                    ),
                  ),
                  Tab(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.white24, width: 1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Completed • Rate Client'),
                    ),
                  ),
                  Tab(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .where(
                            'participants',
                            arrayContains:
                                FirebaseAuth.instance.currentUser!.uid,
                          )
                          .snapshots(),
                      builder: (_, snap) {
                        int total = 0;
                        String myId = FirebaseAuth.instance.currentUser!.uid;
                        if (snap.hasData) {
                          for (var doc in snap.data!.docs) {
                            var map = doc.data() as Map<String, dynamic>;
                            var counts =
                                map['unreadCounts'] as Map<String, dynamic>?;
                            total += ((counts?[myId] as num?)?.toInt() ?? 0);
                          }
                        }
                        return Badge(
                          isLabelVisible: total > 0,
                          label: Text('$total'),
                          child: const Text('Messages'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                children: [
                  FundiHomeJobsTab(
                    search: search,
                    onSearchChanged: (v) =>
                        setState(() => search = v.toLowerCase()),
                    mySkill: mySkill,
                    me: me,
                    completedJobs: completedJobs,
                    relevanceScore: relevanceScore,
                    onBid: bidForJob,
                    currentPos: currentPos,
                  ),
                  const FundiCompletedWrapper(),
                  const ChatListScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
