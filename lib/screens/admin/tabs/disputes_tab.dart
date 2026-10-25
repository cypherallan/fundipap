import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/admin_dispute_detail_screen.dart';

class DisputesTab extends StatelessWidget {
  const DisputesTab({super.key});

  int _badgeRank(String b) {
    b = b.toLowerCase().trim();
    if (b == 'gold') return 0;
    if (b == 'silver') return 1;
    if (b == 'bronze') return 2;
    if (b == 'none' || b == '' || b == 'null') return 3;
    if (b.contains('gold') && (b.contains('trial') || b.contains('test')))
      return 4;
    return 3;
  }

  Color _badgeColor(String b, int rank) {
    if (rank == 0) return const Color(0xFFFFD700);
    if (rank == 1) return const Color(0xFFC0C0C0);
    if (rank == 2) return const Color(0xFFCD7F32);
    if (rank == 4) return Colors.grey.shade300;
    return Colors.black12;
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _statusColor(String status) {
    if (status == 'open') return Colors.orange;
    if (status.contains('payment') || status.contains('disputed'))
      return Colors.red;
    if (status == 'accepted_redo') return Colors.green;
    if (status.contains('evidence')) return Colors.blue;
    if (status.contains('auto_resolved')) return Colors.green;
    if (status.contains('needs_admin')) return Colors.red;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fundis').snapshots(),
      builder: (context, fundiSnap) {
        Map<String, String> badgeMap = {};
        if (fundiSnap.hasData) {
          for (var d in fundiSnap.data!.docs) {
            var m = d.data() as Map;
            badgeMap[d.id] = (m['badge'] ?? m['subscriptionBadge'] ?? 'none')
                .toString();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('disputes')
              .where(
                'status',
                whereIn: [
                  'open',
                  'accepted_redo',
                  'evidence_complete',
                  'awaiting_both',
                  'auto_checking',
                  'needs_admin',
                ],
              )
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty)
              return const Center(child: Text('No open disputes ✓'));

            var raw = snap.data!.docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              String badge =
                  (d['reporterBadge'] ??
                          badgeMap[d['reportedBy']] ??
                          badgeMap[d['fundiId']] ??
                          'none')
                      .toString();
              bool isPaymentDispute =
                  (d['reason'] ?? '').toString().toLowerCase().contains(
                    'payment',
                  ) ||
                  (d['type'] ?? '').toString().contains('payment') ||
                  d.containsKey('partialAmount') ||
                  (d['description'] ?? '').toString().contains('mpesaPayouts');
              return {
                'doc': doc,
                'data': d,
                'badge': badge,
                'rank': _badgeRank(badge),
                'isPayment': isPaymentDispute,
                'createdAt': d['createdAt'] as Timestamp?,
              };
            }).toList();

            // Payment disputes first, then gold, then oldest
            raw.sort((a, b) {
              bool ap = a['isPayment'] as bool;
              bool bp = b['isPayment'] as bool;
              if (ap && !bp) return -1;
              if (!ap && bp) return 1;
              int r = (a['rank'] as int).compareTo(b['rank'] as int);
              if (r != 0) return r;
              Timestamp ta =
                  a['createdAt'] as Timestamp? ??
                  Timestamp.fromDate(DateTime.now());
              Timestamp tb =
                  b['createdAt'] as Timestamp? ??
                  Timestamp.fromDate(DateTime.now());
              return ta.compareTo(tb);
            });

            return ListView(
              padding: const EdgeInsets.all(8),
              children: raw.map((item) {
                var doc = item['doc'] as DocumentSnapshot;
                var d = item['data'] as Map<String, dynamic>;
                String badge = item['badge'] as String;
                int rank = item['rank'] as int;
                bool isPayment = item['isPayment'] as bool;
                Timestamp? ts = item['createdAt'] as Timestamp?;
                String type = d['type'] ?? '';
                String status = d['status'] ?? 'open';
                String autoResult =
                    d['autoCheckResult'] ?? d['autoCheckStatus'] ?? '';
                String autoTier = (d['autoCheckTier'] ?? '').toString();

                return Card(
                  elevation: isPayment ? 4 : (rank == 0 ? 3 : 1),
                  color: isPayment
                      ? Colors.red.shade50
                      : (rank == 0 ? Colors.amber.shade50 : Colors.white),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isPayment
                          ? Colors.red
                          : (rank == 0 ? Colors.amber : Colors.grey.shade300),
                      width: isPayment ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminDisputeDetailScreen(disputeId: doc.id),
                      ),
                    ),
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _badgeColor(badge, rank),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _timeAgo(ts),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      '${isPayment ? '💰 PAYMENT DISPUTE • ' : ''}${d['jobTitle'] ?? ''} • ${type.toUpperCase()}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: isPayment ? Colors.red.shade800 : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reason: ${d['reason'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(status),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (autoResult.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      autoResult.contains('success') ||
                                          autoResult.contains('explained')
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'AUTO: ${autoResult.toUpperCase()} T$autoTier',
                                  style: GoogleFonts.inter(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Job ${d['jobId']?.toString().substring(0, 6) ?? ''} • Client: ${d['clientName'] ?? ''} • Fundi: ${d['fundiName'] ?? ''} • KES ${d['escrowAmount'] ?? d['amount'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 9),
                        ),
                        if (isPayment) ...[
                          const SizedBox(height: 4),
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('mpesaPayouts')
                                .doc(d['jobId'])
                                .get(),
                            builder: (_, pSnap) {
                              if (!pSnap.hasData || !pSnap.data!.exists)
                                return Text(
                                  'Ledger: mpesaPayouts/${d['jobId']} not found',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    color: Colors.red,
                                  ),
                                );
                              var pd =
                                  pSnap.data!.data() as Map<String, dynamic>;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'C2B: ${pd['c2bTransactionId'] ?? ''} • B2C: ${pd['b2cTransactionId'] ?? ''}',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Payout: KES ${pd['amount'] ?? ''} • Fee: ${pd['platformFee'] ?? ''} • Status: ${pd['b2cStatus'] ?? pd['status'] ?? ''}',
                                    style: GoogleFonts.inter(fontSize: 8),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      isPayment ? Icons.warning : Icons.arrow_forward_ios,
                      size: 14,
                      color: isPayment ? Colors.red : null,
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
