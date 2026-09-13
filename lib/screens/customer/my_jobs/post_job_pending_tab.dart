import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ClientPendingTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> jobs;
  final Future<void> Function(BuildContext, DocumentReference, String, double)
  onCounter;
  final Future<void> Function(
    BuildContext,
    DocumentReference,
    String,
    Map<String, dynamic>,
  )
  onAccept;
  final Future<void> Function(BuildContext, String, Map<String, dynamic>)
  onEdit;
  final Future<void> Function(BuildContext, String) onDelete;
  const ClientPendingTab({
    super.key,
    required this.jobs,
    required this.onCounter,
    required this.onAccept,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    if (jobs.isEmpty) {
      return Center(child: Text('No pending jobs', style: GoogleFonts.inter()));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: jobs.length,
      itemBuilder: (_, i) {
        var jobDoc = jobs[i];
        var job = jobDoc.data() as Map<String, dynamic>;
        var jobId = jobDoc.id;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Budget KES ${job['budget']} • ${job['status']}',
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(jobId)
                      .collection('bids')
                      .snapshots(),
                  builder: (_, bidSnap) {
                    if (!bidSnap.hasData) {
                      return const LinearProgressIndicator();
                    }
                    var bids = bidSnap.data!.docs;
                    if (bids.isEmpty) {
                      return Text(
                        'No bids yet',
                        style: GoogleFonts.inter(fontSize: 11),
                      );
                    }
                    return Column(
                      children: bids.map((b) {
                        var bid = b.data() as Map<String, dynamic>;
                        if (bid['status'] == 'rejected') {
                          return const SizedBox.shrink();
                        }
                        bool isMyCounter = bid['lastCounterBy'] == uid;
                        bool isCounteredByMe =
                            bid['status'] == 'countered' && isMyCounter;
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${bid['fundiName'] ?? 'Fundi'} • KES ${bid['lastCounterPrice'] ?? bid['price']}',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (bid['message'] != null)
                                Text(
                                  bid['message'],
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                              if (isCounteredByMe) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'You countered KES ${bid['lastCounterPrice']}. Waiting for fundi to accept...',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const LinearProgressIndicator(),
                              ] else ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => onCounter(
                                          context,
                                          b.reference,
                                          jobId,
                                          (bid['lastCounterPrice'] ??
                                                  bid['price'])
                                              .toDouble(),
                                        ),
                                        child: const Text('Counter'),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              FundipapColors.greenSuccess,
                                        ),
                                        onPressed: () => onAccept(
                                          context,
                                          b.reference,
                                          jobId,
                                          bid,
                                        ),
                                        child: const Text(
                                          'Accept',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onEdit(context, jobId, job),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.redAlert,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => onDelete(context, jobId),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
