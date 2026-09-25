import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const CustomerTrackingScreen({
    super.key,
    required this.jobId,
    required this.job,
  });

  double calculateTransportFee(double distanceMeters) {
    if (distanceMeters <= 1000) return 100; // <=1km = 100 round trip
    double km = distanceMeters / 1000;
    return 100 + ((km - 1) * 60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${job['assignedFundiName'] ?? 'Fundi'} is coming'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var data = snap.data!.data() as Map<String, dynamic>? ?? {};

          // Merge static job + live data - try ALL keys you save
          double? cLat, cLng;
          for (var k in ['customerLat', 'clientLat', 'lat', 'latitude']) {
            if ((job[k] ?? data[k]) != null) {
              cLat = (job[k] ?? data[k] as num).toDouble();
              break;
            }
          }
          for (var k in ['customerLng', 'clientLng', 'lng', 'longitude']) {
            if ((job[k] ?? data[k]) != null) {
              cLng = (job[k] ?? data[k] as num).toDouble();
              break;
            }
          }
          for (var k in [
            'clientLocation',
            'customerLocation',
            'locationGeoPoint',
            'locationGeo',
          ]) {
            var v = job[k] ?? data[k];
            if (v is GeoPoint) {
              cLat = v.latitude;
              cLng = v.longitude;
              break;
            }
          }

          if (cLat == null || cLng == null) {
            return Center(
              child: Text(
                'Client location missing',
                style: GoogleFonts.inter(),
              ),
            );
          }

          double? fLat = (data['fundiLiveLat'] as num?)?.toDouble();
          double? fLng = (data['fundiLiveLng'] as num?)?.toDouble();
          double storedDist =
              (data['fundiLiveDistance'] as num?)?.toDouble() ?? 0;
          bool isTravelling = data['travelling'] == true;

          if (!isTravelling) {
            return Center(
              child: Text(
                'Fundi arrived or cancelled travel',
                style: GoogleFonts.inter(),
              ),
            );
          }

          double dist = storedDist;
          if (fLat != null && fLng != null) {
            double local = Geolocator.distanceBetween(fLat, fLng, cLat, cLng);
            if (dist == 0 || (local - dist).abs() > 200) dist = local;
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
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live • Updates every 10m',
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
                      String url = fLat != null
                          ? 'https://www.google.com/maps/dir/?api=1&origin=$fLat,$fLng&destination=$cLat,$cLng'
                          : 'https://www.google.com/maps/search/?api=1&query=$cLat,$cLng';
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
      ),
    );
  }
}
