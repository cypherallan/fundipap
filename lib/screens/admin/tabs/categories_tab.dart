import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/taxonomy_seed_card.dart';

class CategoriesTab extends StatelessWidget {
  final VoidCallback? onOpenDisputes;
  const CategoriesTab({super.key, this.onOpenDisputes});

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

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaxonomySeedCard(),
          SizedBox(height: 16),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('fundis').snapshots(),
            builder: (context, fundiSnap) {
              Map<String, String> badgeMap = {};
              if (fundiSnap.hasData) {
                for (var d in fundiSnap.data!.docs) {
                  badgeMap[d.id] = ((d.data() as Map)['badge'] ?? 'none')
                      .toString();
                }
              }
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('disputes')
                    .where('status', whereIn: ['open', 'waiting', 'pending'])
                    .snapshots(),
                builder: (context, dispSnap) {
                  if (!dispSnap.hasData) {
                    return Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Checking disputes...',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  var raw = dispSnap.data!.docs.map((doc) {
                    var d = doc.data() as Map<String, dynamic>;
                    String badge =
                        (d['reporterBadge'] ??
                                d['fundiBadge'] ??
                                badgeMap[d['reportedBy']] ??
                                badgeMap[d['reportedUserId']] ??
                                d['reportedUserBadge'] ??
                                'none')
                            .toString();
                    return {
                      'id': doc.id,
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
                        a['createdAt'] as Timestamp? ?? Timestamp.now();
                    Timestamp tb =
                        b['createdAt'] as Timestamp? ?? Timestamp.now();
                    return ta.compareTo(tb);
                  });

                  int openCount = raw.length;
                  if (openCount == 0) {
                    return Container(
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No pending disputes',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: onOpenDisputes,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Icon(
                                      Icons.notifications_active,
                                      color: Colors.white,
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$openCount',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 10),
                                Text(
                                  '$openCount DISPUTES WAITING',
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.white54,
                                ),
                              ],
                            ),
                          ),
                        ),
                        ...raw.take(5).map((item) {
                          var d = item['data'] as Map<String, dynamic>;
                          String badge = item['badge'].toString();
                          return InkWell(
                            onTap: onOpenDisputes,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.black12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item['rank'] == 0
                                          ? Color(0xFFFFD700)
                                          : (item['rank'] == 1
                                                ? Color(0xFFC0C0C0)
                                                : (item['rank'] == 2
                                                      ? Color(0xFFCD7F32)
                                                      : Colors.black12)),
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
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d['reason'] ?? d['type'] ?? 'Dispute',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${d['reportedByName'] ?? d['reportedBy'] ?? ''} • ${_timeAgo(item['createdAt'] as Timestamp?)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (openCount > 5)
                          InkWell(
                            onTap: onOpenDisputes,
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              child: Center(
                                child: Text(
                                  'View all $openCount →',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          SizedBox(height: 24),
          Text(
            'Live Categories',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('categories')
                .orderBy('name')
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              if (snap.data!.docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 40,
                        color: Colors.black26,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No categories yet',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  var d = doc.data() as Map;
                  var subs = (d['subcategories'] as List?) ?? [];
                  return Container(
                    margin: EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Color(0xFFFFD60A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.build, size: 20),
                      ),
                      title: Text(
                        d['name'] ?? doc.id,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '${subs.length} subs • ${d['pricingMode'] ?? 'market'}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
