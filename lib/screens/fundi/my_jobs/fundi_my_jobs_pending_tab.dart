import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiPendingTab extends StatelessWidget {
  final Stream<QuerySnapshot> bidsStream;
  final Future<void> Function(
    DocumentReference bidRef,
    String jobId,
    double price,
  )
  onCounter;
  const FundiPendingTab({
    super.key,
    required this.bidsStream,
    required this.onCounter,
  });

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: bidsStream,
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(child: SelectableText('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var filtered = snap.data!.docs.where((d) {
          var data = d.data() as Map<String, dynamic>;
          return (data['status'] == 'pending' ||
                  data['status'] == 'countered' ||
                  data['status'] == 'bidding') &&
              data['deletedForFundi'] != true;
        }).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No pending offers',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            var bid = filtered[i].data() as Map<String, dynamic>;
            var jobRef = filtered[i].reference.parent.parent;
            return FutureBuilder<DocumentSnapshot>(
              future: jobRef!.get(),
              builder: (_, jobSnap) {
                var job = jobSnap.data?.data() as Map<String, dynamic>?;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENDING • KES ${bid['lastCounterPrice'] ?? bid['price']}',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      Text(
                        job?['title'] ?? 'Job',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        job?['location'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (bid['status'] == 'countered' &&
                          bid['lastCounterBy'] != uid)
                        Text(
                          'Client countered: KES ${bid['lastCounterPrice']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blue,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (bid['status'] == 'countered' &&
                          bid['lastCounterBy'] != uid) ...[
                        Text(
                          'Client countered: KES ${bid['lastCounterPrice']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => onCounter(
                                  filtered[i].reference,
                                  jobRef.id,
                                  (bid['lastCounterPrice'] ?? bid['price'])
                                      .toDouble(),
                                ),
                                child: const Text('Counter'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FundipapColors.greenSuccess,
                                ),
                                onPressed: () async {
                                  await filtered[i].reference.update({
                                    'status': 'pending_client_accept',
                                  });
                                  await FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(jobRef.id)
                                      .update({
                                        'renegotiation': {'requested': false},
                                        'priceHistory': FieldValue.arrayUnion([
                                          {
                                            'price': bid['lastCounterPrice'],
                                            'by': uid,
                                            'type': 'accepted_client_counter',
                                            'at': DateTime.now()
                                                .toIso8601String(),
                                          },
                                        ]),
                                      });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Accepted client KES ${bid['lastCounterPrice']} - waiting client to confirm job',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else if (bid['lastCounterBy'] == uid) ...[
                        Text(
                          'You countered KES ${bid['lastCounterPrice']}. Waiting for client...',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const LinearProgressIndicator(),
                      ] else ...[
                        Text(
                          'Waiting for client to accept your KES ${bid['price']}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
