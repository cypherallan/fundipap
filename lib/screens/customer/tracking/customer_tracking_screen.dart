import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var data = snap.data!.data() as Map<String, dynamic>?;
          double? fLat = (data?['fundiLiveLat'] as num?)?.toDouble();
          double? fLng = (data?['fundiLiveLng'] as num?)?.toDouble();
          double dist = (data?['fundiLiveDistance'] as num?)?.toDouble() ?? 0;
          bool isTravelling = data?['travelling'] == true;

          if (!isTravelling) {
            return Center(
              child: Text(
                'Fundi arrived or cancelled travel',
                style: GoogleFonts.inter(),
              ),
            );
          }

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
                        '${(dist / 1000).toStringAsFixed(1)} km away',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        'Live • Updates every 10m',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fundi shared location only for this trip. Sharing stops when he marks arrived.',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
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
                      double cLat =
                          (job['customerLat'] ?? job['lat'] ?? -0.0917)
                              .toDouble();
                      double cLng =
                          (job['customerLng'] ?? job['lng'] ?? 34.7680)
                              .toDouble();
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
