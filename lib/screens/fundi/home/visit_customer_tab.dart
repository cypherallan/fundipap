// lib/screens/fundi/home/visit_customer_tab.dart - FIXED
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
          .where(
            'status',
            whereIn: [
              'accepted',
              'assigned',
              'confirmed',
              'travelling',
              'site_visit',
              'in_progress',
            ],
          )
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty)
          return Center(
            child: Text(
              'No assigned jobs to visit',
              style: GoogleFonts.inter(),
            ),
          );
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
  double? distance;
  StreamSubscription<Position>? sub;
  bool loading = true;
  String error = '';
  double? clientLat;
  double? clientLng;

  double calculateTransportFee(double meters) {
    if (meters <= 1000) return 100; // YOUR RULE: <=1km = 100 round trip
    double km = meters / 1000;
    return 100 +
        ((km - 1) * 60); // <-- your >1km formula, 60 = per km after first
  }

  @override
  void initState() {
    super.initState();
    _extractClientLatLng();
    _startTracking();
  }

  void _extractClientLatLng() {
    try {
      var geo =
          widget.job['clientLocation'] ??
          widget.job['customerLocation'] ??
          widget.job['locationGeoPoint'];
      if (geo is GeoPoint) {
        clientLat = geo.latitude;
        clientLng = geo.longitude;
      } else if (geo is Map) {
        clientLat = (geo['lat'] ?? geo['latitude'])?.toDouble();
        clientLng = (geo['lng'] ?? geo['longitude'])?.toDouble();
      }
      clientLat ??=
          (widget.job['customerLat'] ??
                  widget.job['clientLat'] ??
                  widget.job['lat'])
              ?.toDouble();
      clientLng ??=
          (widget.job['customerLng'] ??
                  widget.job['clientLng'] ??
                  widget.job['lng'])
              ?.toDouble();
      // NO FALLBACK TO -0.0917,34.7680 - removed!
    } catch (e) {
      error = 'Error parsing client location: $e';
    }
  }

  Future<void> _startTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) {
      setState(() {
        error = 'Location denied forever. Enable from settings.';
        loading = false;
      });
      return;
    }
    sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (p) {
            double? d;
            if (clientLat != null && clientLng != null) {
              d = Geolocator.distanceBetween(
                p.latitude,
                p.longitude,
                clientLat!,
                clientLng!,
              );
            }
            if (mounted) {
              setState(() {
                pos = p;
                distance = d;
                loading = false;
                if (clientLat == null) {
                  error =
                      'Client GPS not saved! Ask client to re-create job with location ON.';
                }
              });
            }
          },
          onError: (e) {
            setState(() {
              error = 'GPS error: $e';
              loading = false;
            });
          },
        );
  }

  Future<void> _openMaps() async {
    if (clientLat == null || clientLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Client GPS missing')));
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$clientLat,$clientLng&travelmode=driving',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open maps: $e')));
    }
  }

  Future<void> _markVisited() async {
    if (clientLat != null && distance != null && distance! > 100) {
      bool? ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${distance!.toStringAsFixed(0)}m away'),
          content: Text(
            'You are ${distance!.toStringAsFixed(0)}m from client point. Confirm anyway?\nClient: $clientLat,$clientLng\nYou: ${pos?.latitude},${pos?.longitude}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('CONFIRM ANYWAY'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _forceConfirm();
  }

  Future<void> _forceConfirm() async {
    double fee = distance != null ? calculateTransportFee(distance!) : 100;
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'siteVisited': true,
          'siteVisitDone': true,
          'siteVisitedAt': FieldValue.serverTimestamp(),
          'fundiLatAtVisit': pos?.latitude, 'fundiLngAtVisit': pos?.longitude,
          'transportDistanceMeters': distance, 'transportFee': fee, // SAVE FEE
          'travelling': false,
          'status': 'site_visit',
          'updatedAt': FieldValue.serverTimestamp(),
          'customerHasUnread': true,
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Site visited ✓ Transport: KES ${fee.toStringAsFixed(0)}',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool canMark = pos != null;
    bool within100 = distance != null && distance! <= 100;
    double fee = distance != null ? calculateTransportFee(distance!) : 100;
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
                  else if (clientLat == null)
                    Text(
                      '⚠ CLIENT GPS MISSING',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          '${distance?.toStringAsFixed(0) ?? '--'}m away',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: within100 ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          'Transport: KES ${fee.toStringAsFixed(0)} ${distance != null && distance! <= 1000 ? '(100 round trip - <=1km rule)' : ''}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Client: ${clientLat!.toStringAsFixed(5)}, ${clientLng!.toStringAsFixed(5)}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  if (pos != null)
                    Text(
                      'You: ${pos!.latitude.toStringAsFixed(5)}, ${pos!.longitude.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    error,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.red),
                  ),
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
                  'Get Directions',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: within100
                      ? FundipapColors.primaryYellow
                      : Colors.orange,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: canMark ? _markVisited : null,
                icon: Icon(within100 ? Icons.check_circle : Icons.location_off),
                label: Text(
                  within100
                      ? 'Mark as Site Visited - KES $fee'
                      : distance != null
                      ? 'Confirm Arrival (${distance!.toStringAsFixed(0)}m) - KES ${fee.toStringAsFixed(0)}'
                      : 'Move closer',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
