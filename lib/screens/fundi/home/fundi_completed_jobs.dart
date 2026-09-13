import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiCompletedJobs extends StatelessWidget {
  const FundiCompletedJobs({super.key});

  Future<void> _showFundiRateClientDialog(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
    Map<String, dynamic>? me,
  ) async {
    int rating = 5;
    final commentCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(
            'Rate Client ${job['customerUsername'] ?? ''}',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      Icons.star,
                      color: i < rating ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () => setSt(() => rating = i + 1),
                  ),
                ),
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: 'How was client?'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                var uid = FirebaseAuth.instance.currentUser!.uid;
                var clientId = job['customerId'] ?? job['clientId'];

                // PASTE YOUR SNIPPET HERE - START
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(clientId)
                    .collection('clientReviews')
                    .add({
                      'fundiId': uid,
                      'fundiName': me?['name'] ?? 'Fundi',
                      'rating': rating,
                      'comment': commentCtrl.text.trim(),
                      'jobId': jobId,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                // calc new client average
                var clientDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(clientId)
                    .get();
                var oldCount =
                    (clientDoc.data()?['clientRatingCount'] ?? 0) as int;
                var oldAvg = (clientDoc.data()?['clientRating'] ?? 4.5)
                    .toDouble();
                var newAvg = ((oldAvg * oldCount) + rating) / (oldCount + 1);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(clientId)
                    .update({
                      'clientRating': newAvg,
                      'clientRatingCount': FieldValue.increment(1),
                    });
                await FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(jobId)
                    .update({'fundiRated': true});
                // END

                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Client rated ✓')));
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('assignedFundi', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data!.docs.isEmpty) {
          return Center(
            child: Text('No completed jobs yet', style: GoogleFonts.inter()),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snap.data!.docs.length,
          itemBuilder: (_, i) {
            var d = snap.data!.docs[i].data() as Map<String, dynamic>;
            var jobId = snap.data!.docs[i].id;
            bool alreadyRated = d['fundiRated'] == true;
            return Card(
              child: ListTile(
                title: Text(d['title'] ?? ''),
                subtitle: Text(
                  'KES ${d['agreedPrice'] ?? d['budget']} • ${d['customerUsername'] ?? 'Client'}',
                ),
                trailing: alreadyRated
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.primaryYellow,
                        ),
                        onPressed: () async {
                          var meDoc = await FirebaseFirestore.instance
                              .collection('fundis')
                              .doc(uid)
                              .get();
                          _showFundiRateClientDialog(
                            context,
                            jobId,
                            d,
                            meDoc.data(),
                          );
                        },
                        child: Text(
                          'Rate Client',
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
