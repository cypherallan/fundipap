import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTrackingScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const CustomerTrackingScreen({
    super.key,
    required this.jobId,
    required this.job,
  });

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  double calculateTransportFee(double distanceMeters) {
    if (distanceMeters <= 1000) return 100;
    double km = distanceMeters / 1000;
    return 100 + ((km - 1) * 60);
  }

  @override
  Widget build(BuildContext context) {
    String fundiId = widget.job['assignedFundi'] ?? widget.job['fundiId'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.job['assignedFundiName'] ?? 'Fundi'} is coming'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .snapshots(),
        builder: (_, jobSnap) {
          if (!jobSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          var jobData = jobSnap.data!.data() as Map<String, dynamic>? ?? {};
          var merged = {...widget.job, ...jobData};

          double? cLat, cLng;
          if (merged['customerLocation'] is GeoPoint) {
            cLat = (merged['customerLocation'] as GeoPoint).latitude;
            cLng = (merged['customerLocation'] as GeoPoint).longitude;
          } else {
            cLat = (merged['customerLat'] ?? merged['clientLat'] as num?)
                ?.toDouble();
            cLng = (merged['customerLng'] ?? merged['clientLng'] as num?)
                ?.toDouble();
          }

          if (cLat == null || cLng == null) {
            return Center(
              child: Text(
                'Client location missing',
                style: GoogleFonts.inter(),
              ),
            );
          }

          if (fundiId.isEmpty) {
            return Center(
              child: Text('Fundi not assigned yet', style: GoogleFonts.inter()),
            );
          }

          // LIVE FROM RTDB - this is the fix
          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('live_locations/$fundiId')
                .onValue,
            builder: (_, liveSnap) {
              double? fLat, fLng;
              if (liveSnap.hasData && liveSnap.data!.snapshot.value != null) {
                var v = Map<String, dynamic>.from(
                  liveSnap.data!.snapshot.value as Map,
                );
                fLat = (v['lat'] as num?)?.toDouble();
                fLng = (v['lng'] as num?)?.toDouble();
              }

              double dist = 0;
              if (fLat != null && fLng != null) {
                dist = Geolocator.distanceBetween(fLat, fLng, cLat!, cLng!);
              }

              if (fLat == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        'Waiting for fundi location...',
                        style: GoogleFonts.inter(),
                      ),
                    ],
                  ),
                );
              }

              double fee = calculateTransportFee(dist);
              String display = dist < 1000
                  ? '${dist.toStringAsFixed(0)}m away'
                  : '${(dist / 1000).toStringAsFixed(2)}km away';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_bike,
                            size: 32,
                            color: Colors.blue.shade800,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            display,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            'Transport: KES ${fee.toStringAsFixed(0)} ${dist <= 1000 ? '(100 round trip)' : ''}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live • Updates every 5 sec from RTDB',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
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
                        onPressed: () async {
                          String url =
                              'https://www.google.com/maps/dir/?api=1&origin=$fLat,$fLng&destination=$cLat,$cLng';
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('Open Live in Google Maps'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
