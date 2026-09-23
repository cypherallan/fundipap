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
            bool visited =
                data['siteVisited'] == true || data['siteVisitDone'] == true;
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
                  '${data['location'] ?? ''}\n${visited ? '✓ Site visited - Go to Notifications to Start Job' : 'Not visited yet'}',
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

  @override
  void initState() {
    super.initState();
    _extractClientLatLng();
    _startTracking();
  }

  void _extractClientLatLng() {
    try {
      // Check all possible places where client lat/lng could be saved
      var geo =
          widget.job['clientLocation'] ??
          widget.job['customerLocation'] ??
          widget.job['locationGeoPoint'] ??
          widget.job['geoPoint'];
      if (geo is GeoPoint) {
        clientLat = geo.latitude;
        clientLng = geo.longitude;
      } else if (geo is Map) {
        clientLat = (geo['lat'] ?? geo['latitude'])?.toDouble();
        clientLng = (geo['lng'] ?? geo['longitude'])?.toDouble();
      }
      // direct fields
      clientLat ??=
          (widget.job['customerLat'] ??
                  widget.job['clientLat'] ??
                  widget.job['lat'] ??
                  widget.job['customerLatitude'])
              ?.toDouble();
      clientLng ??=
          (widget.job['customerLng'] ??
                  widget.job['clientLng'] ??
                  widget.job['lng'] ??
                  widget.job['lon'] ??
                  widget.job['customerLongitude'])
              ?.toDouble();

      // also check nested address
      if (clientLat == null && widget.job['addressLat'] != null) {
        clientLat = (widget.job['addressLat'] as num).toDouble();
        clientLng = (widget.job['addressLng'] as num).toDouble();
      }
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
        error = 'Location permission denied forever. Enable from settings.';
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
                if (clientLat == null)
                  error =
                      'Client GPS not saved in job! Job has no customerLat/customerLng. Distance will show as unknown. Ask client to re-create job with location permission ON.';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Client GPS missing - cannot open maps. Check Firestore job for clientLat/lng',
          ),
        ),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$clientLat,$clientLng&travelmode=driving',
    );
    final fallback = Uri.parse(
      'geo:$clientLat,$clientLng?q=$clientLat,$clientLng(Customer)',
    );

    try {
      // Try google maps first
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      } else {
        // last resort - open in browser
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open maps: $e')));
    }
  }

  Future<void> _markVisited() async {
    // If client GPS missing, allow anyway
    if (clientLat == null || clientLng == null) {
      await _forceConfirm();
      return;
    }
    if (distance != null && distance! > 100) {
      bool? ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${distance!.toStringAsFixed(0)}m away'),
          content: Text(
            'You are ${distance!.toStringAsFixed(0)}m from client saved point. You are probably at the right house but client GPS was saved 1005m away from actual house (fallback to Kisumu). Confirm anyway?\n\nClient: $clientLat, $clientLng\nYou: ${pos?.latitude}, ${pos?.longitude}',
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
          'travelling': false,
          'status': 'site_visit',
          'updatedAt': FieldValue.serverTimestamp(),
          'customerHasUnread': true,
        });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Site visited confirmed ✓ - Now go to Notifications to Start Job or Request New Price',
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
                      '⚠️ CLIENT GPS MISSING - job has no lat/lng',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                      ),
                    )
                  else
                    Text(
                      '${distance?.toStringAsFixed(0) ?? '--'}m away from customer',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: within100 ? Colors.green : Colors.red,
                      ),
                    ),
                  if (clientLat != null)
                    Text(
                      'Client saved: ${clientLat!.toStringAsFixed(5)}, ${clientLng!.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
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
                      ? 'Mark as Site Visited'
                      : distance != null
                      ? 'Confirm Arrival (${distance!.toStringAsFixed(0)}m - Tap to force)'
                      : 'Move closer to enable',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Fix: When client creates job, save clientLocation as GeoPoint. Remove fallback -0.0917,34.7680. That was showing 1005m because it was measuring to Kisumu town, not client house.',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
