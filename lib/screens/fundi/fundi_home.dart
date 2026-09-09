import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import 'fundi_profile.dart';
import '../../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

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

  // Keywords per skill - so electrician sees electric jobs first
  final Map<String, List<String>> skillKeywords = {
    'electrical': [
      'electrical',
      'electrician',
      'electricity',
      'wiring',
      'socket',
      'switch',
      'bulb',
      'light',
      'power',
      'electronics',
    ],
    'plumbing': [
      'plumbing',
      'plumber',
      'pipe',
      'leak',
      'water',
      'tap',
      'sink',
      'toilet',
      'drainage',
    ],
    'carpentry': [
      'carpentry',
      'carpenter',
      'furniture',
      'wood',
      'door',
      'cabinet',
      'table',
      'chair',
      'wardrobe',
    ],
    'masonry': [
      'masonry',
      'mason',
      'construction',
      'building',
      'brick',
      'cement',
      'plaster',
      'wall',
      'floor',
    ],
    'painting': ['painting', 'painter', 'paint', 'wall', 'color', 'decor'],
    'welding': ['welding', 'welder', 'metal', 'gate', 'grill', 'fabrication'],
    'mechanic': ['mechanic', 'car', 'vehicle', 'engine', 'garage', 'motor'],
  };

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
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    var fundiDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(uid)
        .get();
    var jobsDone = await FirebaseFirestore.instance
        .collection('jobs')
        .where('fundiId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    double sum = 0;
    for (var doc in jobsDone.docs) {
      var d = doc.data();
      sum +=
          ((d['finalPrice'] ??
                      d['agreedPrice'] ??
                      d['price'] ??
                      d['budget'] ??
                      0)
                  as num)
              .toDouble();
    }

    if (mounted) {
      var combined = {...?userDoc.data(), ...?fundiDoc.data()};

      // CALCULATE COMPLETION - only 100% if really done
      int pct = 0;
      if ((combined['name'] ?? '').toString().length > 2) pct += 10;
      if ((combined['profession'] ?? combined['skill'] ?? '')
          .toString()
          .isNotEmpty)
        pct += 15;
      if ((combined['bio'] ?? '').toString().length > 20) pct += 20;
      if ((combined['price'] ?? 0) != 0) pct += 10;
      if (combined['photoUrl'] != null) pct += 15;
      if ((combined['phone'] ?? '').toString().length > 5) pct += 5;
      if ((combined['location'] ?? '').toString().isNotEmpty) pct += 5;
      if ((combined['resumes'] as List?)?.isNotEmpty ?? false) pct += 7;
      if ((combined['certificates'] as List?)?.isNotEmpty ?? false) pct += 8;
      if ((combined['portfolio'] as List?)?.isNotEmpty ?? false) pct += 5;

      setState(() {
        me = combined;
        completedJobs = jobsDone.docs.length;
        totalEarned = sum;
        mySkill = (combined['profession'] ?? combined['skill'] ?? 'General')
            .toString()
            .toLowerCase();
        profilePct = pct.clamp(0, 100);
      });
    }
  }

  int _relevanceScore(Map<String, dynamic> job) {
    String text = "${job['title']} ${job['description']} ${job['category']}"
        .toLowerCase();
    int score = 0;
    String keyword = (me?['searchKeyword'] ?? mySkill).toLowerCase();
    List other = me?['otherSkills'] ?? [];
    if (text.contains(keyword)) score += 100;
    if (text.contains(mySkill)) score += 100;
    for (var s in other) {
      if (text.contains(s.toString().toLowerCase())) score += 60;
    }
    // keyword matching from skillKeywords map as before
    return score;
  }

  Future<void> _bidForJob(Map<String, dynamic> job) async {
    final priceCtrl = TextEditingController();
    var uid = FirebaseAuth.instance.currentUser!.uid;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Bid for ${job['title']}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        content: TextField(
          controller: priceCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Your price KES',
            hintText: 'e.g. 1500',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.primaryYellow,
            ),
            onPressed: () async {
              if (priceCtrl.text.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(job['id'])
                  .collection('bids')
                  .doc(uid)
                  .set({
                    'fundiId': uid,
                    'fundiName': me?['name'] ?? 'Fundi',
                    'photoUrl': me?['photoUrl'],
                    'rating': me?['rating'] ?? 4.5,
                    'jobsDone': completedJobs,
                    'price': int.tryParse(priceCtrl.text) ?? 0,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bid sent ✓ client will see it')),
              );
            },
            child: Text(
              'Send Bid',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
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
            Row(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: 74,
                      height: 74,
                      child: CircularProgressIndicator(
                        value: profilePct / 100,
                        strokeWidth: 3,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation(
                          profilePct == 100
                              ? FundipapColors.greenSuccess
                              : FundipapColors.primaryYellow,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: CircleAvatar(
                        radius: 29,
                        backgroundColor: FundipapColors.primaryYellow,
                        backgroundImage: me?['photoUrl'] != null
                            ? NetworkImage(me!['photoUrl'])
                            : null,
                        child: me?['photoUrl'] == null
                            ? Text(
                                (me?['name'] ?? 'F')[0].toUpperCase(),
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      // change InkWell to GestureDetector too
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FundiProfile(),
                            ),
                          );
                          _loadMe();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: FundipapColors.primaryYellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    if (profilePct == 100)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: FundipapColors.greenSuccess,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Habari, ${me?['name'] ?? 'Fundi'}',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        me?['profession'] ?? me?['skill'] ?? 'Fundi',
                        style: GoogleFonts.inter(
                          color: FundipapColors.primaryYellow,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      // SHOW OTHER SKILLS AS CHIPS - for your case
                      if ((me?['otherSkills'] as List?)?.isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: (me!['otherSkills'] as List).take(4).map((
                            s,
                          ) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                s.toString(),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: FundipapColors.primaryYellow,
                            size: 14,
                          ),
                          Text(
                            ' ${me?['rating'] ?? 4.9} • $completedJobs jobs',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 10,
                            ),
                          ),
                          if (profilePct == 100) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: FundipapColors.greenSuccess,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'VERIFIED',
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: FundipapColors.greenSuccess,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ONLINE',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (profilePct < 100)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FundipapColors.primaryYellow.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$profilePct%',
                      style: GoogleFonts.montserrat(
                        color: FundipapColors.primaryYellow,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete your profile to get noticed',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'You are at $profilePct% - clients prefer 100%',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FundipapColors.greenSuccess.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FundipapColors.greenSuccess),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: FundipapColors.greenSuccess,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '100% Complete - you rank higher!',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            if (me?['bio'] != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  me!['bio'],
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FundipapColors.primaryYellow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL EARNED • ONLY YOU SEE THIS',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    me == null
                        ? 'KES --'
                        : 'KES ${totalEarned.toStringAsFixed(0)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'From $completedJobs completed jobs • Platform fee paid by customer',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat('$completedJobs', 'Done'),
                      _stat('${me?['rating'] ?? 5.0}', 'Rating'),
                      _stat('$profilePct%', 'Profile'),
                    ],
                  ),
                ],
              ),
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
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isMatch
                            ? Colors.white
                            : Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: isMatch
                            ? Border.all(
                                color: FundipapColors.primaryYellow,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isMatch
                                      ? FundipapColors.primaryYellow
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (data['category'] ?? 'General')
                                      .toString()
                                      .toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (isMatch) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FundipapColors.greenSuccess,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'FOR YOU',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                'KES ${data['budget'] ?? 1500}',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['title'] ?? 'Job',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.place,
                                size: 12,
                                color: Colors.black45,
                              ),
                              Text(
                                ' ${data['location'] ?? 'Kisumu'} • ${data['distance'] ?? '1.2km'}',
                                style: GoogleFonts.inter(fontSize: 10),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () => _bidForJob(data),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FundipapColors.blackGray,
                                  minimumSize: const Size(0, 30),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                child: Text(
                                  'BID',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _stat(String v, String l) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(v, style: GoogleFonts.montserrat(fontWeight: FontWeight.w800)),
            Text(l, style: GoogleFonts.inter(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
