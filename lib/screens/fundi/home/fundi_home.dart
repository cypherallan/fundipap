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
import 'fundi_notifications_banner.dart';

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
            // This now slides like your CustomerBidNotifications
            const FundiNotificationsBanner(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: EdgeInsets.zero,
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
