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
    if (b.contains('gold') && (b.contains('trial') || b.contains('test'))) {
      return 4;
    }
    return 3;
  }

  Color _badgeColor(String b, int rank) {
    if (rank == 0) return Color(0xFFFFD700);
    if (rank == 1) return Color(0xFFC0C0C0);
    if (rank == 2) return Color(0xFFCD7F32);
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
    if (status == 'accepted_redo') return Colors.green;
    if ((status).contains('evidence')) return Colors.blue;
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
                ],
              )
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            if (snap.data!.docs.isEmpty) {
              return Center(child: Text('No open disputes ✓'));
            }

            var raw = snap.data!.docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              String badge =
                  (d['reporterBadge'] ??
                          badgeMap[d['reportedBy']] ??
                          badgeMap[d['fundiId']] ??
                          'none')
                      .toString();
              return {
                'doc': doc,
                'data': d,
                'badge': badge,
                'rank': _badgeRank(badge),
                'createdAt': d['createdAt'] as Timestamp?,
              };
            }).toList();

            raw.sort((a, b) {
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
              padding: EdgeInsets.all(8),
              children: raw.map((item) {
                var doc = item['doc'] as DocumentSnapshot;
                var d = item['data'] as Map<String, dynamic>;
                String badge = item['badge'] as String;
                int rank = item['rank'] as int;
                Timestamp? ts = item['createdAt'] as Timestamp?;
                String type = d['type'] ?? '';
                String status = d['status'] ?? 'open';
                bool hasEvidence =
                    (d['reporterEvidenceSubmitted'] == true) ||
                    (d['reportedEvidenceSubmitted'] == true);
                bool bothEvidence =
                    (d['reporterEvidenceSubmitted'] == true) &&
                    (d['reportedEvidenceSubmitted'] == true);
                bool acceptedRedo = d['fundiAcceptedRedo'] == true;

                return Card(
                  elevation: rank == 0 ? 3 : 1,
                  color: rank == 0
                      ? Colors.amber.shade50
                      : acceptedRedo
                      ? Colors.green.shade50
                      : Colors.white,
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
                          padding: EdgeInsets.symmetric(
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
                        SizedBox(height: 4),
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
                      '${d['jobTitle'] ?? ''} • ${type.toUpperCase()} ${acceptedRedo ? "[ACCEPTED REDO]" : ""}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
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
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
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
                            SizedBox(width: 6),
                            if (bothEvidence)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'BOTH EVIDENCE ✓',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (!bothEvidence && hasEvidence)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '1 SIDE EVIDENCE',
                                  style: GoogleFonts.inter(fontSize: 8),
                                ),
                              ),
                            if (!hasEvidence)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'NO EVIDENCE YET',
                                  style: GoogleFonts.inter(fontSize: 8),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Job ${d['jobId']?.toString().substring(0, 6) ?? ''} • Client: ${d['clientName'] ?? ''} • Fundi: ${d['fundiName'] ?? ''} • KES ${d['escrowAmount'] ?? ''}',
                          style: GoogleFonts.inter(fontSize: 9),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Icon(Icons.arrow_forward_ios, size: 14),
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
