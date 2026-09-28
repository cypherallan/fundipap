import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ClientCancelledTab extends StatefulWidget {
  final List<QueryDocumentSnapshot> docs;
  const ClientCancelledTab({super.key, required this.docs});

  @override
  State<ClientCancelledTab> createState() => _ClientCancelledTabState();
}

class _ClientCancelledTabState extends State<ClientCancelledTab> {
  final Set<String> _reposting = {};

  Future<void> _repostSameDetails(
    BuildContext context,
    Map<String, dynamic> oldJob,
    String oldJobId,
  ) async {
    if (_reposting.contains(oldJobId)) return;
    setState(() => _reposting.add(oldJobId));

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      final existing = await db
          .collection('jobs')
          .where('repostedFrom', isEqualTo: oldJobId)
          .where('customerId', isEqualTo: uid)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        await db.collection('jobs').doc(oldJobId).update({
          'reposted': true,
          'repostedAs': existing.docs.first.id,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Already reposted - check Pending tab'),
            ),
          );
        }
        return;
      }

      final newRef = db.collection('jobs').doc();
      final Map<String, dynamic> newJob = {
        'customerId': uid,
        'customerName':
            oldJob['customerName'] ??
            oldJob['clientName'] ??
            oldJob['customerUsername'] ??
            'Client',
        'clientName':
            oldJob['clientName'] ?? oldJob['customerName'] ?? 'Client',
        'customerUsername':
            oldJob['customerUsername'] ?? oldJob['customerName'],
        'title': oldJob['title'],
        'description': oldJob['description'],
        'categoryId': oldJob['categoryId'],
        'subcategoryId': oldJob['subcategoryId'],
        'categoryName': oldJob['categoryName'],
        'subcategoryName': oldJob['subcategoryName'],
        'faultId': oldJob['faultId'],
        'budget':
            oldJob['budget'] ??
            oldJob['currentLabour'] ??
            oldJob['agreedPrice'],
        'transportFee': oldJob['transportFee'] ?? 0,
        'images': oldJob['images'] ?? [],
        'location': oldJob['location'],
        'latitude': oldJob['latitude'],
        'longitude': oldJob['longitude'],
        'address': oldJob['address'],
        'status': 'open',
        'cancelled': false,
        'escrowStatus': 'pending',
        'escrowAmount': 0,
        'agreedPrice': null,
        'assignedFundiId': null,
        'repostedFrom': oldJobId,
        'repostedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await newRef.set(newJob);
      await db.collection('jobs').doc(oldJobId).update({
        'reposted': true,
        'repostedAs': newRef.id,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Reposted! Same details - getting new fundi bids',
            ),
            backgroundColor: FundipapColors.greenSuccess,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _reposting.remove(oldJobId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) {
      return Center(
        child: Text(
          'No cancelled jobs',
          style: GoogleFonts.inter(color: Colors.black54),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.docs.length,
      itemBuilder: (_, i) {
        var doc = widget.docs[i];
        var job = doc.data() as Map<String, dynamic>;
        bool beforeEscrow =
            (job['escrowAmount'] ?? 0) == 0 &&
            (job['escrowStatus'] ?? 'pending') != 'held';
        bool isReposting = _reposting.contains(doc.id);
        bool alreadyReposted = job['reposted'] == true; // <-- key check
        String cancelledBy = (job['cancelledBy'] ?? '')
            .toString()
            .toLowerCase();
        String fundiName =
            (job['assignedFundiName'] ?? job['fundiName'] ?? 'Fundi')
                .toString();
        bool isFundiCancelled = cancelledBy == 'fundi';

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
                      isFundiCancelled ? 'By $fundiName' : 'By You',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (alreadyReposted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'REPOSTED',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: Colors.green.shade700,
                          ),
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
                  child: beforeEscrow
                      ? Text(
                          isFundiCancelled
                              ? '$fundiName cancelled this job before you paid to escrow. No charge.'
                              : 'You cancelled this job before you paid to escrow.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Column(
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
                            Text(
                              'Fee: KES ${job['platformFee'] ?? 0} | Refund: KES ${job['clientRefund'] ?? 0}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.red.shade700,
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
                      backgroundColor: alreadyReposted
                          ? Colors.grey.shade300
                          : FundipapColors.primaryYellow,
                      foregroundColor: alreadyReposted
                          ? Colors.black54
                          : Colors.black,
                    ),
                    onPressed: (isReposting || alreadyReposted)
                        ? null
                        : () => _repostSameDetails(context, job, doc.id),
                    icon: isReposting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            alreadyReposted ? Icons.check_circle : Icons.replay,
                            size: 16,
                          ),
                    label: Text(
                      alreadyReposted
                          ? 'Job Reposted ✓'
                          : isReposting
                          ? 'Reposting...'
                          : 'Repost Same Details for New Bids',
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
