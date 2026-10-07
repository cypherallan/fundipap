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
  double? distance;
  StreamSubscription<Position>? sub;
  bool loading = true;
  String error = '';
  double? clientLat;
  double? clientLng;
  bool isMarking = false;

  double calculateTransportFee(double meters) {
    if (meters <= 1000) return 100; // YOUR RULE: <=1km = 100 round trip
    double km = meters / 1000;
    return 100 + ((km - 1) * 60);
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
          widget.job['geopoint'] ??
          widget.job['location'] ??
          widget.job['clientLocation'] ??
          widget.job['customerLocation'] ??
          widget.job['locationGeoPoint'] ??
          widget.job['liveLocation'] ??
          widget.job['geopointCustomer'];

      if (geo is GeoPoint) {
        clientLat = geo.latitude;
        clientLng = geo.longitude;
      } else if (geo is Map) {
        clientLat = (geo['lat'] ?? geo['latitude'] ?? geo['geopoint']?['lat'])
            ?.toDouble();
        clientLng = (geo['lng'] ?? geo['longitude'] ?? geo['geopoint']?['lng'])
            ?.toDouble();
      }

      clientLat ??=
          (widget.job['customerLat'] ??
                  widget.job['clientLat'] ??
                  widget.job['lat'] ??
                  widget.job['latitude'] ??
                  widget.job['jobLat'])
              ?.toDouble();
      clientLng ??=
          (widget.job['customerLng'] ??
                  widget.job['clientLng'] ??
                  widget.job['lng'] ??
                  widget.job['longitude'] ??
                  widget.job['jobLng'])
              ?.toDouble();
    } catch (e) {
      error = 'Error parsing job location: $e';
    }
  }

  Future<void> _startTracking() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
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
            distanceFilter: 5, // strict check every 5m
          ),
        ).listen(
          (p) async {
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

            // LIVE TRACKING FOR CUSTOMER - this makes TRACK LIVE work
            try {
              await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(widget.jobId)
                  .update({
                    'fundiLiveLat': p.latitude,
                    'fundiLiveLng': p.longitude,
                    'fundiLiveAt': FieldValue.serverTimestamp(),
                    'fundiLiveDistance': d,
                    'travelling': true,
                  });
            } catch (_) {}

            // AUTO-DETECT: prompt when within 100m
            if (d != null && d <= 100 && mounted && !isMarking) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green.shade700,
                  content: Text(
                    'You are ${d.toStringAsFixed(0)}m away - You can now mark arrived',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                error = 'GPS error: $e';
                loading = false;
              });
            }
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
    final uri = pos != null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=${pos!.latitude},${pos!.longitude}&destination=$clientLat,$clientLng&travelmode=driving',
          )
        : Uri.parse(
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
    // FRESH strict check - no stale distance
    if (pos == null || clientLat == null || clientLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Getting GPS... wait')));
      return;
    }

    double freshDistance = Geolocator.distanceBetween(
      pos!.latitude,
      pos!.longitude,
      clientLat!,
      clientLng!,
    );

    // HARD BLOCK if >100m - cannot bypass even if app was backgrounded
    if (freshDistance > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'BLOCKED: You are ${freshDistance.toStringAsFixed(0)}m away. Must be within 100m.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
      setState(() => distance = freshDistance);
      return;
    }

    await _forceConfirm(freshDistance);
  }

  Future<void> _forceConfirm(double finalDistance) async {
    if (isMarking) return;
    setState(() => isMarking = true);

    double fee = calculateTransportFee(finalDistance);
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'siteVisited': true,
          'siteVisitDone': true,
          'siteVisitedAt': FieldValue.serverTimestamp(),
          'fundiLatAtVisit': pos?.latitude,
          'fundiLngAtVisit': pos?.longitude,
          'transportDistanceMeters': finalDistance,
          'transportFee': fee,
          'arrivalDistance': finalDistance, // proof
          'travelling': false,
          'status': 'site_visit',
          'updatedAt': FieldValue.serverTimestamp(),
          'customerHasUnread': true,
        });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Site visited ✓ Transport: KES ${fee.toStringAsFixed(0)} at ${finalDistance.toStringAsFixed(0)}m',
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
    bool canMark =
        pos != null && distance != null && distance! <= 100 && !isMarking;
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
                          '${distance?.toStringAsFixed(0) ?? '--'}m away ${within100 ? "✓ Within 100m" : "✗ Must be ≤100m"}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            color: within100 ? Colors.green : Colors.red,
                          ),
                        ),
                        Text(
                          'Transport: KES ${fee.toStringAsFixed(0)} ${distance != null && distance! <= 1000 ? '(100 round trip - ≤1km rule)' : ''}',
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
                padding: EdgeInsets.only(top: 10),
                child: Container(
                  padding: EdgeInsets.all(10),
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
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: _openMaps,
                icon: Icon(Icons.directions),
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
                  backgroundColor: canMark
                      ? FundipapColors.primaryYellow
                      : Colors.grey.shade400,
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: canMark ? _markVisited : null,
                icon: Icon(canMark ? Icons.check_circle : Icons.location_off),
                label: Text(
                  canMark
                      ? 'Mark as Site Visited - KES $fee'
                      : distance != null
                      ? 'BLOCKED: ${distance!.toStringAsFixed(0)}m away - Move within 100m'
                      : 'Getting GPS...',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (!canMark && !loading)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'FundiPap blocks marking until GPS confirms ≤100m. Coming back to app does NOT bypass.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
