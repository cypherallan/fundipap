import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientRejectedTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> allJobDocs;
  const ClientRejectedTab({super.key, required this.allJobDocs});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allJobDocs.length,
      itemBuilder: (_, i) {
        var jobId = allJobDocs[i].id;
        var jobData = allJobDocs[i].data() as Map<String, dynamic>;
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .collection('bids')
              .where('status', isEqualTo: 'rejected')
              .snapshots(),
          builder: (_, bidSnap) {
            if (!bidSnap.hasData || bidSnap.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            var bids = bidSnap.data!.docs
                .where((b) => (b.data() as Map)['deletedForClient'] != true)
                .toList();
            if (bids.isEmpty) return const SizedBox.shrink();
            return Column(
              children: bids.map((bidDoc) {
                var bid = bidDoc.data() as Map<String, dynamic>;
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
                        await bidDoc.reference.update({
                          'deletedForClient': true,
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
