import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fundi_card.dart';

class CustomerHomeFundiList extends StatelessWidget {
  final Position? userPos;
  final double radius;
  final String filter;
  const CustomerHomeFundiList({
    super.key,
    required this.userPos,
    required this.radius,
    required this.filter,
  });

  double _calcDistance(double lat, double lng) {
    if (userPos == null) return 0;
    return Geolocator.distanceBetween(
          userPos!.latitude,
          userPos!.longitude,
          lat,
          lng,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fundis').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Text('No fundis available yet', style: GoogleFonts.inter()),
          );
        }

        var docs = snap.data!.docs
            .map((d) {
              var data = d.data() as Map<String, dynamic>;
              double lat = (data['lat'] ?? -0.0917).toDouble();
              double lng = (data['lng'] ?? 34.7680).toDouble();
              double dist = userPos == null
                  ? (data['distance'] ?? 1.0).toDouble()
                  : _calcDistance(lat, lng);
              return {...data, 'id': d.id, 'calcDistance': dist};
            })
            .where((f) => (f['calcDistance'] as double) <= radius)
            .toList();

        if (filter == 'distance') {
          docs.sort(
            (a, b) => (a['calcDistance'] as double).compareTo(
              b['calcDistance'] as double,
            ),
          );
        } else if (filter == 'rated')
          // ignore: curly_braces_in_flow_control_structures
          docs.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
        else if (filter == 'cheap')
          // ignore: curly_braces_in_flow_control_structures
          docs.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        else if (filter == 'expensive')
          // ignore: curly_braces_in_flow_control_structures
          docs.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  'No fundis within ${radius.toStringAsFixed(1)}km',
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) => CustomerHomeFundiCard(fundi: docs[i]),
        );
      },
    );
  }
}
