import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/fundi_request_new_price.dart';

class FundiNotificationsPage extends StatelessWidget {
  const FundiNotificationsPage({super.key});

  Future<void> _startSiteVisit(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisitCustomerScreen(jobId: jobId, job: job),
      ),
    );
  }

  void _openNewPrice(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundiRequestNewPriceScreen(jobId: jobId, job: job),
      ),
    );
  }

  Future<void> _startJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
      builder: (context, jobsSnap) {
        Map<String, Map<String, dynamic>> escrowMap = {};
        Map<String, Map<String, dynamic>> visitedMap = {};
        Map<String, Map<String, dynamic>> travellingMap = {};

        if (jobsSnap.hasData) {
          for (var doc in jobsSnap.data!.docs) {
            var job = doc.data() as Map<String, dynamic>;
            bool isMine =
                job['assignedFundiId'] == uid ||
                job['assignedFundi'] == uid ||
                job['fundiId'] == uid ||
                job['acceptedFundiId'] == uid;
            if (!isMine) continue;

            var escrow = (job['escrowStatus'] ?? 'pending').toString();
            var status = (job['status'] ?? '').toString();
            bool siteDone = job['siteVisitDone'] == true;
            var reneg = job['renegotiation'] as Map<String, dynamic>?;

            // 1. Escrow paid -> must start visit
            if ((escrow == 'paid' || escrow == 'held') &&
                (status == 'assigned' || status == 'confirmed')) {
              escrowMap[doc.id] = {'jobId': doc.id, 'job': job};
            }
            // 2. You are travelling
            else if ((job['travelling'] == true || status == 'travelling') &&
                !siteDone) {
              travellingMap[doc.id] = {'jobId': doc.id, 'job': job};
            }
            // 3. Site visited - same as ConfirmedTab shows
            else if (siteDone &&
                status == 'site_visit' &&
                (reneg == null || reneg['requested'] != true)) {
              visitedMap[doc.id] = {'jobId': doc.id, 'job': job};
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collectionGroup('bids')
              .where('fundiId', isEqualTo: uid)
              .snapshots(),
          builder: (context, bidsSnap) {
            List<Widget> cards = [];

            // ESCROW PAID
            for (var e in escrowMap.values) {
              var job = e['job'] as Map<String, dynamic>;
              cards.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: FundipapColors.blackGray,
                            child: Icon(
                              Icons.lock_open,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Client paid to escrow!',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'KES ${job['escrowAmount'] ?? job['agreedPrice'] ?? ''} locked • ${job['title'] ?? ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.blackGray,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                          ),
                          icon: const Icon(Icons.navigation, size: 20),
                          label: Text(
                            'Start Site Visit - Must Visit First',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: () =>
                              _startSiteVisit(context, e['jobId'], job),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // TRAVELLING
            for (var e in travellingMap.values) {
              var job = e['job'] as Map<String, dynamic>;
              cards.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.directions_bike, color: Colors.blue.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are travelling to ${job['title'] ?? ''} • ${(job['fundiLiveDistance'] ?? 0).toStringAsFixed(0)}m away',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // SITE VISITED - same UI as ConfirmedTab
            for (var e in visitedMap.values) {
              var job = e['job'] as Map<String, dynamic>;
              var jobId = e['jobId'] as String;
              cards.add(
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: FundipapColors.greenSuccess),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${job['status'].toString().toUpperCase()} • KES ${job['agreedPrice'] ?? job['budget']}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        job['title'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✓ Site visited. Client notified. Status: ${job['status']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _startJob(jobId),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FundipapColors.greenSuccess,
                              ),
                              child: const Text(
                                'START JOB',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _openNewPrice(context, jobId, job),
                              child: const Text('Request New Price'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            // Bids accepted (only if no escrow yet)
            if (bidsSnap.hasData) {
              for (var bidDoc in bidsSnap.data!.docs) {
                var bid = bidDoc.data() as Map<String, dynamic>;
                var jobId = (bid['jobId'] ?? bidDoc.reference.parent.id)
                    .toString();
                if (escrowMap.containsKey(jobId) ||
                    visitedMap.containsKey(jobId) ||
                    travellingMap.containsKey(jobId))
                  continue;
                if (bid['status'] == 'accepted') {
                  cards.add(
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: FundipapColors.primaryYellow),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: FundipapColors.blackGray,
                            child: Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bid accepted! Client confirmed you',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${bid['jobTitle'] ?? 'Job'} • Waiting for escrow',
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            }

            if (cards.isEmpty) {
              return Center(
                child: Text('No notifications', style: GoogleFonts.inter()),
              );
            }
            return ListView(padding: const EdgeInsets.all(12), children: cards);
          },
        );
      },
    );
  }
}

class _VisitCustomerScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const _VisitCustomerScreen({required this.jobId, required this.job});
  @override
  State<_VisitCustomerScreen> createState() => _VisitCustomerScreenState();
}

class _VisitCustomerScreenState extends State<_VisitCustomerScreen> {
  Position? currentPos;
  double distance = 999999;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _track();
  }

  Future<void> _track() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) async {
      double lat = (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
          .toDouble();
      double lng = (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
          .toDouble();
      double d = Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng);
      if (mounted) {
        setState(() {
          currentPos = p;
          distance = d;
          loading = false;
        });
      }
      try {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'fundiLiveLat': p.latitude,
              'fundiLiveLng': p.longitude,
              'fundiLiveAt': FieldValue.serverTimestamp(),
              'fundiLiveDistance': d,
            });
      } catch (_) {}
    });
  }

  Future<void> _openMaps() async {
    double lat = (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
        .toDouble();
    double lng = (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
        .toDouble();
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _confirmVisited() async {
    if (distance > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are ${distance.toStringAsFixed(0)}m away. Get within 100m',
          ),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'siteVisitDone': true,
          'siteVisited': true,
          'siteVisitedAt': FieldValue.serverTimestamp(),
          'fundiLatAtVisit': currentPos?.latitude,
          'fundiLngAtVisit': currentPos?.longitude,
          'travelling': false,
          'status': 'site_visit',
        });
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Site visit confirmed with GPS')),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canMark = distance <= 100;
    return Scaffold(
      appBar: AppBar(
        title: Text('Visit ${widget.job['customerName'] ?? 'Customer'}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  Text(
                    widget.job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.job['location'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    Text(
                      '${distance.toStringAsFixed(0)}m away',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: canMark ? Colors.green : Colors.red,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _openMaps,
                icon: const Icon(Icons.directions),
                label: const Text('Open Directions in Maps'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canMark
                      ? FundipapColors.primaryYellow
                      : Colors.grey.shade300,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: canMark ? _confirmVisited : null,
                icon: Icon(canMark ? Icons.check_circle : Icons.location_off),
                label: Text(
                  canMark
                      ? 'I have arrived - Mark Site Visited'
                      : 'Move within 100m to mark',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
