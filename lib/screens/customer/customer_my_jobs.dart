import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';

class CustomerMyJobs extends StatelessWidget {
  const CustomerMyJobs({super.key});

  Future<void> _deleteJob(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Delete Job?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove it completely. Fundis will no longer see it.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.redAlert,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    var bids = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .get();
    for (var doc in bids.docs) {
      await doc.reference.delete();
    }
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Job deleted')));
  }

  Future<void> _editJob(BuildContext context, Map<String, dynamic> job) async {
    final titleCtrl = TextEditingController(text: job['title']);
    final descCtrl = TextEditingController(text: job['description']);
    final minCtrl = TextEditingController(text: job['budgetMin'].toString());
    final maxCtrl = TextEditingController(text: job['budgetMax'].toString());
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
          children: [
            Text(
              'Edit Job',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
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
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
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
                      labelText: 'Min',
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
                      labelText: 'Max',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('jobs')
                      .doc(job['id'])
                      .update({
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'budgetMin':
                            int.tryParse(minCtrl.text) ?? job['budgetMin'],
                        'budgetMax':
                            int.tryParse(maxCtrl.text) ?? job['budgetMax'],
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job updated'),
                      backgroundColor: FundipapColors.greenSuccess,
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _payToEscrow(String jobId, double amount) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'escrowStatus': 'held',
      'escrowAmount': amount,
      'escrowHeldAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveNewPrice(String jobId, double newPrice) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'agreedPrice': newPrice,
      'budget': newPrice,
      'budgetMax': newPrice,
      'renegotiation.status': 'approved',
      'renegotiation.approvedAt': FieldValue.serverTimestamp(),
      'status': 'assigned',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _rejectNewPrice(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.status': 'rejected',
      'renegotiation.rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // FIXED: Release INITIAL + NEW REVIEWED COST
  Future<void> _confirmCompletion(String jobId) async {
    var doc = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .get();
    var j = doc.data() as Map<String, dynamic>;
    var reneg = j['renegotiation'] as Map<String, dynamic>?;

    int initialAmount =
        (j['escrowAmount'] ?? j['agreedPrice'] ?? j['budgetMax'] ?? 0).toInt();
    int extraAmount =
        (j['extraLaborAmount'] ??
                reneg?['extraLabor'] ??
                reneg?['pendingLabor'] ??
                0)
            .toInt();
    int newLaborTotal = (reneg?['newLaborTotal'] ?? 0).toInt();

    // Total to release = newLaborTotal if exists, else initial + extra
    int totalRelease = newLaborTotal > 0
        ? newLaborTotal
        : initialAmount + extraAmount;
    if (totalRelease == 0) totalRelease = initialAmount;

    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
      'escrowStatus': 'released',
      'extraEscrowStatus': 'released',
      'clientConfirmedComplete': true,
      'completedAt': FieldValue.serverTimestamp(),
      'totalReleasedAmount': totalRelease,
      'fundiPayoutAmount': totalRelease,
      'initialEscrowReleased': initialAmount,
      'extraEscrowReleased': extraAmount,
      'fundiHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('customerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'You haven\'t posted any jobs yet',
              style: GoogleFonts.inter(),
            ),
          );
        }
        var jobs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: jobs.length,
          itemBuilder: (_, i) {
            var doc = jobs[i];
            var j = doc.data() as Map<String, dynamic>;
            j['id'] = doc.id;
            String status = j['status'] ?? 'open';
            String escrow = j['escrowStatus'] ?? 'pending';
            bool siteDone = j['siteVisitDone'] ?? false;
            var reneg = j['renegotiation'] as Map<String, dynamic>?;
            int initialAmt =
                (j['escrowAmount'] ?? j['agreedPrice'] ?? j['budgetMax'] ?? 0)
                    .toInt();
            int extraAmt = (j['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0)
                .toInt();
            int newTotal = (reneg?['newLaborTotal'] ?? 0).toInt();
            int totalToRelease = newTotal > 0
                ? newTotal
                : initialAmt + extraAmt;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          j['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'open'
                              ? FundipapColors.greenSuccess.withOpacity(0.15)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    j['description'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'KES ${j['budgetMin']} - ${j['budgetMax']} • Agreed: KES ${j['agreedPrice'] ?? '-'} • Extra: KES $extraAmt • Total: KES $totalToRelease',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),

                  if (siteDone) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fundi visited site',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                if (j['siteVisitFindings'] != null)
                                  Text(
                                    j['siteVisitFindings'],
                                    style: GoogleFonts.inter(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (reneg != null && reneg['status'] == 'pending') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fundi requests new price: KES ${reneg['newPrice']}',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${reneg['reason'] ?? ''}',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                          if (reneg['photos'] != null &&
                              (reneg['photos'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Site photos:',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: (reneg['photos'] as List).length,
                                itemBuilder: (_, idx) => Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      (reneg['photos'] as List)[idx],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _rejectNewPrice(doc.id),
                                  child: const Text(
                                    'Reject',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        FundipapColors.greenSuccess,
                                  ),
                                  onPressed: () => _approveNewPrice(
                                    doc.id,
                                    (reneg['newPrice'] as num).toDouble(),
                                  ),
                                  child: const Text(
                                    'Approve & Pay Diff',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (status == 'assigned' && escrow != 'held') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.primaryYellow,
                        ),
                        onPressed: () => _payToEscrow(
                          doc.id,
                          (j['agreedPrice'] ?? j['budgetMax'] ?? 1000)
                              .toDouble(),
                        ),
                        child: Text(
                          'PAY KES ${j['agreedPrice'] ?? j['budgetMax']} TO ESCROW (Mpesa)',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (status == 'in_progress') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Text(
                        'Fundi is working... Initial KES $initialAmt + Extra KES $extraAmt = Total KES $totalToRelease in escrow',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  if (status == 'job_completed' ||
                      status == 'pending_completion') ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fundi marked job as completed',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                          Text(
                            'Initial: KES $initialAmt + Extra: KES $extraAmt = Total KES $totalToRelease will be released to fundi',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.greenSuccess,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () => _confirmCompletion(doc.id),
                        child: Text(
                          'CONFIRM COMPLETION & RELEASE KES $totalToRelease TO FUNDI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],

                  if (status == 'completed') ...[
                    const SizedBox(height: 10),
                    Text(
                      '✓ Completed & Paid KES ${j['totalReleasedAmount'] ?? totalToRelease} (Initial $initialAmt + Extra $extraAmt)',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  if (status == 'open')
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _editJob(context, j),
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(
                              'Edit',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FundipapColors.redAlert,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _deleteJob(context, doc.id),
                            icon: const Icon(Icons.delete, size: 16),
                            label: Text(
                              'Delete',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
