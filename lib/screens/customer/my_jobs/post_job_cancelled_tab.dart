import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ClientCancelledTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const ClientCancelledTab({super.key, required this.docs});

  Future<void> _repostSameDetails(
    BuildContext context,
    Map<String, dynamic> oldJob,
    String oldJobId,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final newRef = db.collection('jobs').doc();

    // clone only what client posted - reset all flow fields
    final Map<String, dynamic> newJob = {
      'customerId': uid,
      'title': oldJob['title'],
      'description': oldJob['description'],
      'categoryId': oldJob['categoryId'],
      'subcategoryId': oldJob['subcategoryId'],
      'categoryName': oldJob['categoryName'],
      'subcategoryName': oldJob['subcategoryName'],
      'faultId': oldJob['faultId'],
      'budget':
          oldJob['budget'] ?? oldJob['currentLabour'] ?? oldJob['agreedPrice'],
      'transportFee': oldJob['transportFee'] ?? 0,
      'images': oldJob['images'] ?? [],
      'location': oldJob['location'],
      'latitude': oldJob['latitude'],
      'longitude': oldJob['longitude'],
      'address': oldJob['address'],

      'status': 'open', // back to bidding
      'escrowStatus': 'pending',
      'escrowAmount': 0,
      'agreedPrice': null,
      'assignedFundi': null,
      'assignedFundiId': null,
      'repostedFrom': oldJobId,
      'repostedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await newRef.set(newJob);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reposted! Same details - getting new fundi bids'),
          backgroundColor: FundipapColors.greenSuccess,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No cancelled jobs',
          style: GoogleFonts.inter(color: Colors.black54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var doc = docs[i];
        var job = doc.data() as Map<String, dynamic>;
        bool beforeEscrow =
            (job['escrowAmount'] ?? 0) == 0 &&
            (job['escrowStatus'] ?? 'pending') != 'held';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CANCELLED',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      job['cancelledAt'] != null ? 'Cancelled' : '',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  job['title'] ?? '',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${job['categoryName'] ?? job['categoryId']} > ${job['subcategoryName'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Labour: KES ${job['currentLabour'] ?? job['agreedPrice'] ?? job['budget'] ?? 0}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          Text(
                            'Transport: KES ${job['transportFee'] ?? 0}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${job['cancelReason'] ?? 'No reason'}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      if (!beforeEscrow)
                        Text(
                          'Fee: KES ${job['platformFee'] ?? 0} | Refund: KES ${job['clientRefund'] ?? 0}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.red.shade700,
                          ),
                        ),
                      if (beforeEscrow)
                        Text(
                          'No fee - no money was locked',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.green.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.primaryYellow,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => _repostSameDetails(context, job, doc.id),
                    icon: const Icon(Icons.replay, size: 16),
                    label: Text(
                      'Repost Same Details for New Bids',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
