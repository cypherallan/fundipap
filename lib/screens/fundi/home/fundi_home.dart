import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';
import 'home_actions.dart';
import 'header_section.dart';
import 'jobs_tab.dart';
import 'completed_wrapper.dart';
import '../../chats/chat_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../rating/rate_client_screen.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadLocation(context);
      _enforcePendingRating();
    });
  }

  Future<void> _onRefresh() async {
    await loadMe();
    if (mounted) {
      await loadLocation(context);
    }
    await _enforcePendingRating();
    if (mounted) setState(() {});
  }

  Future<void> _enforcePendingRating() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    try {
      final opt = const GetOptions(source: Source.server);
      var s1 = await FirebaseFirestore.instance
          .collection('jobs')
          .where('acceptedBidId', isEqualTo: uid)
          .get(opt);
      var s2 = await FirebaseFirestore.instance
          .collection('jobs')
          .where('fundiId', isEqualTo: uid)
          .get(opt);
      var s3 = await FirebaseFirestore.instance
          .collection('jobs')
          .where('assignedFundiId', isEqualTo: uid)
          .get(opt);

      final map = <String, QueryDocumentSnapshot>{};
      for (var d in [...s1.docs, ...s2.docs, ...s3.docs]) map[d.id] = d;
      final unrated = map.values
          .where(
            (d) => (d.data() as Map<String, dynamic>)['fundiRated'] != true,
          )
          .toList();

      if (unrated.isNotEmpty && mounted) {
        var first = unrated.first;
        var data = first.data() as Map<String, dynamic>;
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => RateClientScreen(
              jobId: first.id,
              clientId: (data['customerId'] ?? data['clientId'] ?? '')
                  .toString(),
              clientName:
                  (data['customerName'] ?? data['clientName'] ?? 'Client')
                      .toString(),
              trade: (data['subcategoryName'] ?? data['title'] ?? '')
                  .toString(),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('LOCK ERR $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: FundipapColors.blackGray,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: FundipapColors.primaryYellow,
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: FundiHomeHeaderSection(
                    me: me,
                    profilePct: profilePct,
                    completedJobs: completedJobs,
                    totalEarned: totalEarned,
                    onReloadMe: loadMe,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: FundipapColors.blackGray,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
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
                                      right: BorderSide(
                                        color: Colors.white24,
                                        width: 1,
                                      ),
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
                                      right: BorderSide(
                                        color: Colors.white24,
                                        width: 1,
                                      ),
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
                                        arrayContains: FirebaseAuth
                                            .instance
                                            .currentUser!
                                            .uid,
                                      )
                                      .snapshots(),
                                  builder: (_, snap) {
                                    int total = 0;
                                    String myId =
                                        FirebaseAuth.instance.currentUser!.uid;
                                    if (snap.hasData) {
                                      for (var doc in snap.data!.docs) {
                                        var map =
                                            doc.data() as Map<String, dynamic>;
                                        var counts =
                                            map['unreadCounts']
                                                as Map<String, dynamic>?;
                                        total +=
                                            ((counts?[myId] as num?)?.toInt() ??
                                            0);
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
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: Container(
              color: FundipapColors.blackGray,
              child: TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: FundiHomeJobsTab(
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
                  ),
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: const FundiCompletedWrapper(),
                  ),
                  RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: const ChatListScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
