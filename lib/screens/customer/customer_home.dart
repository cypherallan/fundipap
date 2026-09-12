import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_home_header.dart';
import 'widgets/customer_bid_notifications.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  double _radius = 5.0;
  String _filter = 'distance';
  Position? _userPos;
  bool _loadingLoc = true;
  Map<String, dynamic>? _me;

  Future<void> _loadMe() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) setState(() => _me = doc.data());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getLocation();
      _loadMe();
    });
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _loadingLoc = false);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(
              'Enable Location',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
            content: Text(
              'FundiPap needs location to find fundis near you in Kisumu.',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await Geolocator.openLocationSettings();
                },
                child: const Text('Turn On'),
              ),
            ],
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _loadingLoc = false);
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Permission Needed'),
            content: const Text(
              'Location permission is permanently denied. Open settings to allow.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Geolocator.openAppSettings();
                },
                child: const Text('Settings'),
              ),
            ],
          ),
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() => _loadingLoc = false);
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _userPos = pos;
        _loadingLoc = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingLoc = false);
    }
  }

  double _calcDistance(double fundiLat, double fundiLng) {
    if (_userPos == null) return 0.0; // will show all if no loc
    return Geolocator.distanceBetween(
          _userPos!.latitude,
          _userPos!.longitude,
          fundiLat,
          fundiLng,
        ) /
        1000; // km
  }

  Future<void> _showHireSheet(Map<String, dynamic> fundi) async {
    final titleCtrl = TextEditingController(
      text: "Need ${fundi['skill'] ?? 'Fundi'}",
    );
    final descCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: "500");
    final maxCtrl = TextEditingController(text: "2000");

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post Job & Invite ${fundi['name']}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Job Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Describe task',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Min Budget',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max Budget',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  // create job
                  var jobRef = await FirebaseFirestore.instance
                      .collection('jobs')
                      .add({
                        'title': titleCtrl.text,
                        'description': descCtrl.text,
                        'category': fundi['skill'] ?? 'General',
                        'budgetMin': int.tryParse(minCtrl.text) ?? 0,
                        'budgetMax': int.tryParse(maxCtrl.text) ?? 0,
                        'status': 'open',
                        'customerId': FirebaseAuth.instance.currentUser!.uid,
                        'invitedFundi': fundi['id'],
                        'lat': _userPos?.latitude ?? -0.0917,
                        'lng': _userPos?.longitude ?? 34.7680,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                  // auto create first bid invite for this fundi
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Job posted - fundis will bid. Average will show here.',
                      ),
                    ),
                  );
                  _showBidsForJob(jobRef.id);
                },
                child: Text(
                  'Post Job',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showBidsForJob(String jobId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, scrollCtrl) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .collection('bids')
              .orderBy('price')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData)
              return Center(child: CircularProgressIndicator());
            var bids = snap.data!.docs;
            double avg = 0;
            if (bids.isNotEmpty) {
              avg =
                  bids
                      .map((d) => (d['price'] ?? 0) as num)
                      .reduce((a, b) => a + b) /
                  bids.length;
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    bids.isEmpty
                        ? 'No bids yet (0 fundis)'
                        : 'Average: KES ${avg.toStringAsFixed(0)} • ${bids.length} bids',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: bids.length,
                    itemBuilder: (_, i) {
                      var b = bids[i].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text((b['fundiName'] ?? 'F')[0]),
                        ),
                        title: Text(
                          '${b['fundiName']} • KES ${b['price']}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${b['rating']}★ • ${b['jobsDone']} jobs done • 0 fraud',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {},
                          child: Text('Accept'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: FundipapColors.blackGray,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: CustomerHomeHeader(
            me: _me,
            profilePct: 75,
            completedJobs: 0,
            onProfileTap: () {},
          ),
        ),
        // FILTER BAR
        // BID NOTIFICATIONS ROW
        const CustomerBidNotifications(),

        // FILTER BAR
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fundis Near You',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FundipapColors.primaryYellow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_radius.toStringAsFixed(1)} km',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radius,
                min: 1,
                max: 20,
                divisions: 19,
                label: '${_radius.toStringAsFixed(1)} km',
                activeColor: FundipapColors.blackGray,
                onChanged: (v) => setState(() => _radius = v),
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('Nearest', 'distance', Icons.near_me),
                    _chip('Top Rated', 'rated', Icons.star),
                    _chip('Cheapest', 'cheap', Icons.arrow_upward),
                    _chip('Price High', 'expensive', Icons.arrow_downward),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_loadingLoc) const LinearProgressIndicator(),
        // REAL FIRESTORE LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('fundis').snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'No fundis available yet',
                    style: GoogleFonts.inter(),
                  ),
                );
              }

              var docs = snap.data!.docs
                  .map((d) {
                    var data = d.data() as Map<String, dynamic>;
                    double lat = (data['lat'] ?? -0.0917).toDouble();
                    double lng = (data['lng'] ?? 34.7680).toDouble();
                    double dist = _userPos == null
                        ? (data['distance'] ?? 1.0).toDouble()
                        : _calcDistance(lat, lng);
                    return {...data, 'id': d.id, 'calcDistance': dist};
                  })
                  .where((f) => (f['calcDistance'] as double) <= _radius)
                  .toList();

              // sort
              if (_filter == 'distance') {
                docs.sort(
                  (a, b) => (a['calcDistance'] as double).compareTo(
                    b['calcDistance'] as double,
                  ),
                );
              } else if (_filter == 'rated') {
                docs.sort(
                  (a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0),
                );
              } else if (_filter == 'cheap') {
                docs.sort(
                  (a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0),
                );
              } else if (_filter == 'expensive') {
                docs.sort(
                  (a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0),
                );
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No fundis within ${_radius.toStringAsFixed(1)}km',
                        style: GoogleFonts.inter(),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  var f = docs[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: FundipapColors.primaryYellow,
                          child: Text(
                            (f['name'] ?? 'F')[0],
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    f['name'] ?? 'Fundi',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (f['verified'] == true)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.verified,
                                        size: 14,
                                        color: FundipapColors.greenSuccess,
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                '${f['skill'] ?? 'General'} • ${f['jobs'] ?? 0} jobs',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                  Text(
                                    ' ${f['rating'] ?? 4.5}',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.place,
                                    size: 14,
                                    color: Colors.black45,
                                  ),
                                  Text(
                                    ' ${(f['calcDistance'] as double).toStringAsFixed(1)} km',
                                    style: GoogleFonts.inter(fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'KES ${f['price'] ?? 0}',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showHireSheet(f),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'Hire',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, String value, IconData icon) {
    bool selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        selectedColor: FundipapColors.primaryYellow,
        onSelected: (_) => setState(() => _filter = value),
        labelStyle: GoogleFonts.montserrat(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
