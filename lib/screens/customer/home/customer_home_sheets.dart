import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class CustomerHomeSheets {
  static Future<void> showHireSheet(
    BuildContext context,
    Map<String, dynamic> fundi,
    Position? userPos,
  ) async {
    final titleCtrl = TextEditingController(
      text: "Need ${fundi['skill'] ?? 'Fundi'}",
    );
    final descCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: "500");
    final maxCtrl = TextEditingController(text: "2000");

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Post Job & Invite ${fundi['name']}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Job Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Describe task',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Min Budget',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max Budget',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  var jobRef = await FirebaseFirestore.instance
                      .collection('jobs')
                      .add({
                        'title': titleCtrl.text,
                        'description': descCtrl.text,
                        'category': fundi['skill'] ?? 'General',
                        'budgetMin': int.tryParse(minCtrl.text) ?? 0,
                        'budgetMax': int.tryParse(maxCtrl.text) ?? 0,
                        'status': 'open',
                        'customerId': FirebaseAuth.instance.currentUser!.uid,
                        'invitedFundi': fundi['id'],
                        'lat': userPos?.latitude ?? -0.0917,
                        'lng': userPos?.longitude ?? 34.7680,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job posted - fundis will bid.'),
                    ),
                  );
                  showBidsForJob(context, jobRef.id);
                },
                child: Text(
                  'Post Job',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static void showBidsForJob(BuildContext context, String jobId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, scrollCtrl) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .collection('bids')
              .orderBy('price')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            var bids = snap.data!.docs;
            double avg = bids.isEmpty
                ? 0
                : bids
                          .map((d) => (d['price'] ?? 0) as num)
                          .reduce((a, b) => a + b) /
                      bids.length;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    bids.isEmpty
                        ? 'No bids yet (0 fundis)'
                        : 'Average: KES ${avg.toStringAsFixed(0)} • ${bids.length} bids',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: bids.length,
                    itemBuilder: (_, i) {
                      var b = bids[i].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text((b['fundiName'] ?? 'F')[0]),
                        ),
                        title: Text(
                          "${b['fundiName']} • KES ${b['price']}",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          "${b['rating']}★ • ${b['jobsDone']} jobs done",
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {},
                          child: const Text('Accept'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
