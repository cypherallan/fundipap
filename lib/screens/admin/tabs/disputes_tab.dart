import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  Widget build(BuildContext context) {
    // 1. Get fundi badges map first
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

        // 2. Then get open disputes - NO orderBy, we sort in memory
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('disputes')
              .where('status', isEqualTo: 'open')
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData)
              return Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty)
              return Center(child: Text('No open disputes ✓'));

            var raw = snap.data!.docs.map((doc) {
              var d = doc.data() as Map<String, dynamic>;
              // badge can be stored at creation, or we lookup fundi who reported
              String badge =
                  (d['reporterBadge'] ??
                          d['fundiBadge'] ??
                          d['clientBadge'] ??
                          badgeMap[d['reportedBy']] ??
                          badgeMap[d['fundiId']] ??
                          badgeMap[d['clientId']] ??
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

            // SORT: gold -> silver -> bronze -> none -> gold_trial, then OLDEST FIRST
            raw.sort((a, b) {
              int r = (a['rank'] as int).compareTo(b['rank'] as int);
              if (r != 0) return r;
              Timestamp ta =
                  a['createdAt'] as Timestamp? ??
                  Timestamp.fromDate(DateTime.now());
              Timestamp tb =
                  b['createdAt'] as Timestamp? ??
                  Timestamp.fromDate(DateTime.now());
              return ta.compareTo(tb); // oldest first
            });

            return ListView(
              padding: EdgeInsets.all(8),
              children: raw.map((item) {
                var doc = item['doc'] as DocumentSnapshot;
                var d = item['data'] as Map<String, dynamic>;
                String badge = item['badge'] as String;
                int rank = item['rank'] as int;
                Timestamp? ts = item['createdAt'] as Timestamp?;

                String role = d['reporterRole'] ?? 'unknown';

                return Card(
                  elevation: rank == 0 ? 3 : 1,
                  color: rank == 0 ? Colors.amber.shade50 : Colors.white,
                  child: ListTile(
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
                      '${d['jobTitle'] ?? ''} • ${d['type'] ?? ''} • by ${role.toUpperCase()} • ${badge.toUpperCase()}',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    subtitle: Text(
                      'Reason: ${d['reason'] ?? ''}\nJob ${d['jobId']?.toString().substring(0, 6) ?? ''} • Client: ${d['clientName'] ?? ''} • Fundi: ${d['fundiName'] ?? ''} • KES ${d['escrowAmount'] ?? ''}',
                      style: GoogleFonts.inter(fontSize: 10),
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            await doc.reference.update({
                              'status': 'resolved_client_win',
                              'resolvedAt': FieldValue.serverTimestamp(),
                            });
                            if (d['jobId'] != null) {
                              await FirebaseFirestore.instance
                                  .collection('jobs')
                                  .doc(d['jobId'])
                                  .update({
                                    'status': 'cancelled',
                                    'escrowStatus': 'refunded',
                                  });
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await doc.reference.update({
                              'status': 'resolved_fundi_win',
                              'resolvedAt': FieldValue.serverTimestamp(),
                            });
                            if (d['jobId'] != null) {
                              await FirebaseFirestore.instance
                                  .collection('jobs')
                                  .doc(d['jobId'])
                                  .update({'status': 'completed'});
                            }
                          },
                        ),
                      ],
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
