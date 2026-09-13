import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_theme.dart';
import 'fundi_home_actions.dart';
import 'fundi_home_header_section.dart';
import 'fundi_home_jobs_tab.dart';
import 'fundi_home_completed_wrapper.dart';

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
    return DefaultTabController(
      length: 2,
      child: Container(
        color: FundipapColors.blackGray,
        child: Column(
          children: [
            FundiHomeHeaderSection(
              me: me,
              profilePct: profilePct,
              completedJobs: completedJobs,
              totalEarned: totalEarned,
              onReloadMe: loadMe,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
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
                tabs: const [
                  Tab(text: 'Jobs Near You'),
                  Tab(text: 'Completed • Rate Client'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
