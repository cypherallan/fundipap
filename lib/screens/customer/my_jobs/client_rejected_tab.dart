import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientRejectedTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> allJobDocs;
  const ClientRejectedTab({super.key, required this.allJobDocs});

  Future<List<Map<String, dynamic>>> _getRejected() async {
    List<Map<String, dynamic>> result = [];
    for (var jobDoc in allJobDocs) {
      var jobData = jobDoc.data() as Map<String, dynamic>;
      var bidSnap = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobDoc.id)
          .collection('bids')
          .where('status', isEqualTo: 'rejected')
          .get();

      for (var b in bidSnap.docs) {
        var data = b.data();
        if (data['deletedForClient'] == true) continue;
        result.add({'bidDoc': b, 'bid': data, 'jobData': jobData});
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (allJobDocs.isEmpty) {
      return Center(
        child: Text(
          'You have not rejected any job',
          style: GoogleFonts.inter(color: Colors.black45),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getRejected(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var rejected = snap.data ?? [];
        if (rejected.isEmpty) {
          return Center(
            child: Text(
              'You have not rejected any job',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rejected.length,
          itemBuilder: (_, i) {
            var item = rejected[i];
            var bidDoc = item['bidDoc'] as QueryDocumentSnapshot;
            var bid = item['bid'] as Map<String, dynamic>;
            var jobData = item['jobData'] as Map<String, dynamic>;
            return Card(
              color: Colors.red.shade50,
              child: ListTile(
                title: Text(
                  '${jobData['title']}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  'Fundi: ${bid['fundiName'] ?? 'Fundi'} • KES ${bid['price']}\n${bid['rejectionReason'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () async {
                    await bidDoc.reference.update({'deletedForClient': true});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
