import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';

class FundiVisitCustomerTab extends StatelessWidget {
  const FundiVisitCustomerTab({super.key});

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('assignedFundi', isEqualTo: uid)
          .where('status', whereIn: ['accepted', 'assigned', 'in_progress'])
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No assigned jobs to visit',
              style: GoogleFonts.inter(),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            var doc = snap.data!.docs[i];
            var data = doc.data() as Map<String, dynamic>;
            bool visited = data['siteVisited'] == true;
            return Card(
              color: visited ? Colors.green.shade50 : Colors.white,
              child: ListTile(
                title: Text(
                  data['title'] ?? 'Job',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${data['location'] ?? ''}\n${visited ? '✓ Site visited' : 'Not visited yet'}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                trailing: visited
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.primaryYellow,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                VisitCustomerScreen(jobId: doc.id, job: data),
                          ),
                        ),
                        child: Text(
                          'Visit',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class VisitCustomerScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const VisitCustomerScreen({
    super.key,
    required this.jobId,
    required this.job,
  });

  @override
  State<VisitCustomerScreen> createState() => _VisitCustomerScreenState();
}

class _VisitCustomerScreenState extends State<VisitCustomerScreen> {
  Position? pos;
  double distance = 999999;
  StreamSubscription<Position>? sub;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((p) {
          double lat =
              (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
                  .toDouble();
          double lng =
              (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
                  .toDouble();
          double d = Geolocator.distanceBetween(
            p.latitude,
            p.longitude,
            lat,
            lng,
          );
          if (mounted) {
            setState(() {
              pos = p;
              distance = d;
              loading = false;
            });
          }
        });
  }

  Future<void> _openMaps() async {
    double lat = (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
        .toDouble();
    double lng = (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
        .toDouble();
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markVisited() async {
    if (distance > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are ${distance.toStringAsFixed(0)}m away. Move closer to customer (within 100m)',
          ),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'siteVisited': true,
          'siteVisitDone': true,
          'siteVisitedAt': FieldValue.serverTimestamp(),
          'siteVisitedBy': FirebaseAuth.instance.currentUser!.uid,
          'fundiLatAtVisit': pos?.latitude,
          'fundiLngAtVisit': pos?.longitude,
          'status': 'in_progress',
        });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Site visited confirmed ✓')));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canMark = distance <= 100;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Visit ${widget.job['customerUsername'] ?? 'Customer'}',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                      '${distance.toStringAsFixed(0)}m away from customer',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: canMark ? Colors.green : Colors.red,
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
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _openMaps,
                icon: const Icon(Icons.directions),
                label: Text(
                  'Get Directions to Customer',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
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
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: canMark ? _markVisited : null,
                icon: Icon(canMark ? Icons.check_circle : Icons.location_off),
                label: Text(
                  canMark ? 'Mark as Site Visited' : 'Move closer to enable',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You must be within 100m of customer home to mark visited. This prevents fake check-ins.',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
