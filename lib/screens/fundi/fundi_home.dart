import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import 'fundi_profile.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

import 'fundi_home_logic.dart';
import 'fundi_bid_dialog.dart';
import 'fundi_home_header.dart';
import 'fundi_profile_banners.dart';
import 'fundi_earnings_card.dart';
import 'fundi_job_card.dart';

class FundiHome extends StatefulWidget {
  const FundiHome({super.key});
  @override
  State<FundiHome> createState() => _FundiHomeState();
}

class _FundiHomeState extends State<FundiHome> {
  String search = '';
  Map<String, dynamic>? me;
  int completedJobs = 0;
  double totalEarned = 0;
  int profilePct = 0;
  String mySkill = 'General';
  Position? currentPos;

  @override
  void initState() {
    super.initState();
    _loadMe();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocation();
    });
  }

  Future<void> _loadLocation() async {
    var pos = await LocationService.determinePosition(context);
    if (pos == null) return;
    if (!mounted) return;
    setState(() => currentPos = pos);
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'location': 'Kisumu',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Location save error: $e');
    }
  }

  Future<void> _loadMe() async {
    final result = await FundiHomeLogic.loadMe();
    if (mounted) {
      setState(() {
        me = result.me;
        completedJobs = result.completedJobs;
        totalEarned = result.totalEarned;
        mySkill = result.mySkill;
        profilePct = result.profilePct;
      });
    }
  }

  int _relevanceScore(Map<String, dynamic> job) {
    return FundiHomeLogic.relevanceScore(job, me, mySkill);
  }

  Future<void> _bidForJob(Map<String, dynamic> job) async {
    await showFundiBidDialog(
      context: context,
      job: job,
      me: me,
      completedJobs: completedJobs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FundipapColors.blackGray,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ADVERT CARD WITH + ICON + COMPLETION CIRCLE
            FundiHomeHeader(
              me: me,
              profilePct: profilePct,
              completedJobs: completedJobs,
              onProfileTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FundiProfile()),
                );
                _loadMe();
              },
            ),
            const SizedBox(height: 14),
            if (profilePct < 100)
              FundiProfileIncompleteBanner(profilePct: profilePct)
            else
              const FundiProfileCompleteBanner(),
            if (me?['bio'] != null) ...[
              const SizedBox(height: 16),
              FundiBioCard(bio: me!['bio']),
            ],
            const SizedBox(height: 24),
            Text(
              'Your Earnings',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            FundiEarningsCard(
              me: me,
              totalEarned: totalEarned,
              completedJobs: completedJobs,
              profilePct: profilePct,
            ),
            const SizedBox(height: 20),

            // SEARCH + FILTER CHIP
            TextField(
              onChanged: (v) => setState(() => search = v.toLowerCase()),
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(
                    'For You: $mySkill',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  backgroundColor: FundipapColors.primaryYellow,
                ),
                Chip(
                  label: Text(
                    'Kisumu • 5km',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                  backgroundColor: Colors.white10,
                  labelStyle: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Home • Jobs Near You',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Showing $mySkill jobs first',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 12),

            // SMART JOBS STREAM
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('status', isEqualTo: 'open')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: FundipapColors.primaryYellow,
                    ),
                  );
                }
                var docs = snap.data!.docs
                    .map(
                      (d) => {'id': d.id, ...d.data() as Map<String, dynamic>},
                    )
                    .toList();

                // SEARCH FILTER
                if (search.isNotEmpty) {
                  docs = docs
                      .where(
                        (m) =>
                            "${m['title']} ${m['description']} ${m['category']}"
                                .toLowerCase()
                                .contains(search),
                      )
                      .toList();
                }

                // SMART SORT BY MY SKILL
                docs.sort(
                  (a, b) => _relevanceScore(b).compareTo(_relevanceScore(a)),
                );

                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No jobs for $mySkill yet.\nPost your advert to get clients.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.white60),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length > 10 ? 10 : docs.length,
                  itemBuilder: (_, i) {
                    var data = docs[i];
                    int score = _relevanceScore(data);
                    bool isMatch = score > 0;
                    return FundiJobCard(
                      data: data,
                      isMatch: isMatch,
                      onBid: () => _bidForJob(data),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
