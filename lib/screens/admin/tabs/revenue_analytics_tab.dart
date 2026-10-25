import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class RevenueAnalyticsTab extends StatefulWidget {
  const RevenueAnalyticsTab({super.key});
  @override
  State<RevenueAnalyticsTab> createState() => _RevenueAnalyticsTabState();
}

class _RevenueAnalyticsTabState extends State<RevenueAnalyticsTab> {
  String _filterCat = 'All';

  double _getAgreed(Map<String, dynamic> d) {
    if (d['lastCounterAmount'] != null) {
      return (d['lastCounterAmount'] as num).toDouble();
    }
    if (d['laborCost'] != null) return (d['laborCost'] as num).toDouble();
    if (d['agreedAmount'] != null) return (d['agreedAmount'] as num).toDouble();
    if (d['acceptedBidAmount'] != null) {
      return (d['acceptedBidAmount'] as num).toDouble();
    }
    if (d['finalAmount'] != null) return (d['finalAmount'] as num).toDouble();
    if (d['totalClientPays'] != null) {
      return (d['totalClientPays'] as num).toDouble() / 1.05;
    }
    if (d['escrowAmount'] != null) {
      return (d['escrowAmount'] as num).toDouble() / 1.05;
    }
    if (d['budget'] != null) return (d['budget'] as num).toDouble();
    if (d['budgetMax'] != null) return (d['budgetMax'] as num).toDouble();
    if (d['agreedPrice'] != null) return (d['agreedPrice'] as num).toDouble();
    return 0;
  }

  double _badgePct(String b) {
    switch (b.toLowerCase()) {
      case 'gold':
      case 'gold_trial':
      case 'gold trial':
        return 0.05;
      case 'silver':
        return 0.08;
      case 'bronze':
        return 0.10;
      default:
        return 0.15;
    }
  }

  String _getServiceName(Map<String, dynamic> d) {
    String cat = (d['categoryName'] ?? d['categoryId'] ?? 'Other').toString();
    String sub = (d['subcategoryName'] ?? d['subcategoryId'] ?? 'General')
        .toString();
    String a = (d['faultName'] ?? '').toString().trim();
    String b = (d['serviceName'] ?? '').toString().trim();
    String c = (d['title'] ?? '').toString().trim();
    String d1 = (d['description'] ?? '').toString().trim();

    if (a.isNotEmpty) return a;
    if (b.isNotEmpty) return b;
    if (c.isNotEmpty) return c;
    if (d1.isNotEmpty) return d1.length > 30 ? d1.substring(0, 30) : d1;
    return '$cat • $sub';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF5F5F3),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fundis').snapshots(),
        builder: (context, fundiSnap) {
          Map<String, String> badgeMap = {};
          if (fundiSnap.hasData) {
            for (var doc in fundiSnap.data!.docs) {
              badgeMap[doc.id] = ((doc.data() as Map)['badge'] ?? 'none')
                  .toString();
            }
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where(
                  'status',
                  whereIn: ['completed', 'job_completed', 'pending_completion'],
                )
                .snapshots(),
            builder: (context, jobSnap) {
              if (!jobSnap.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              double grandTotal = 0,
                  grandClient = 0,
                  grandFundi = 0,
                  grandAgreed = 0;
              int grandCount = 0;
              Set<String> allCats = {'All'};
              List<Map<String, dynamic>> flat = [];
              for (var doc in jobSnap.data!.docs) {
                var d = doc.data() as Map<String, dynamic>;
                double agreed = _getAgreed(d);
                if (agreed <= 0) continue;
                String cat = (d['categoryName'] ?? d['categoryId'] ?? 'Other')
                    .toString();
                String sub =
                    (d['subcategoryName'] ?? d['subcategoryId'] ?? 'General')
                        .toString();
                String srv = _getServiceName(d);
                String fid = d['assignedFundiId'] ?? '';
                String badge = d['fundiBadge'] ?? badgeMap[fid] ?? 'none';
                double c = agreed * 0.05,
                    f = agreed * _badgePct(badge),
                    t = c + f;
                allCats.add(cat);
                grandTotal += t;
                grandClient += c;
                grandFundi += f;
                grandAgreed += agreed;
                grandCount++;
                flat.add({
                  'cat': cat,
                  'sub': sub,
                  'service': srv,
                  'agreed': agreed,
                  'client': c,
                  'fundi': f,
                  'total': t,
                });
              }
              Map<String, Map<String, dynamic>> agg = {};
              for (var r in flat) {
                String k = '${r['cat']}|${r['sub']}|${r['service']}';
                agg.putIfAbsent(
                  k,
                  () => {
                    'cat': r['cat'],
                    'sub': r['sub'],
                    'service': r['service'],
                    'agreed': 0.0,
                    'client': 0.0,
                    'fundi': 0.0,
                    'total': 0.0,
                    'count': 0,
                  },
                );
                agg[k]!['agreed'] += r['agreed'];
                agg[k]!['client'] += r['client'];
                agg[k]!['fundi'] += r['fundi'];
                agg[k]!['total'] += r['total'];
                agg[k]!['count']++;
              }
              var rows = agg.values.toList()
                ..sort((a, b) => b['total'].compareTo(a['total']));
              if (_filterCat != 'All') {
                rows = rows.where((e) => e['cat'] == _filterCat).toList();
              }
              double filteredTotal = rows.fold(0.0, (s, e) => s + e['total']);

              return SingleChildScrollView(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        double w = (c.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: w,
                              child: _card(
                                'GRAND TOTAL',
                                'KES ${grandTotal.toStringAsFixed(0)}',
                                '${grandCount} jobs',
                                true,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: _card(
                                'AGREED',
                                'KES ${grandAgreed.toStringAsFixed(0)}',
                                'Base',
                                false,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: _card(
                                'CLIENT 5%',
                                'KES ${grandClient.toStringAsFixed(0)}',
                                'Escrow',
                                false,
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: _card(
                                'FUNDI',
                                'KES ${grandFundi.toStringAsFixed(0)}',
                                'Badge',
                                false,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: allCats
                          .map(
                            (cat) => ChoiceChip(
                              label: Text(
                                cat,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              selected: _filterCat == cat,
                              selectedColor: FundipapColors.primaryYellow,
                              onSelected: (_) =>
                                  setState(() => _filterCat = cat),
                            ),
                          )
                          .toList(),
                    ),
                    SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              Color(0xFF1A1A1A),
                            ),
                            dataRowColor: MaterialStateProperty.all(
                              Colors.white,
                            ),
                            dataRowMinHeight: 62,
                            dataRowMaxHeight: 62,
                            headingRowHeight: 44,
                            columns: [
                              DataColumn(label: _th('SERVICE')),
                              DataColumn(label: _th('CATEGORY')),
                              DataColumn(label: _th('SUB')),
                              DataColumn(
                                label: _th('JOBS', c: true),
                                numeric: true,
                              ),
                              DataColumn(
                                label: _th('AGREED', c: true),
                                numeric: true,
                              ),
                              DataColumn(
                                label: _th('CLIENT', c: true),
                                numeric: true,
                              ),
                              DataColumn(
                                label: _th('FUNDI', c: true),
                                numeric: true,
                              ),
                              DataColumn(
                                label: _th('YOUR CUT', c: true, yellow: true),
                                numeric: true,
                              ),
                            ],
                            rows: rows.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        r['service'].toString(),
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      r['cat'],
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      r['sub'],
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        '${r['count']}',
                                        style: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${r['agreed'].toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${r['client'].toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 11),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '${r['fundi'].toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 11),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFFD60A),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'KES ${r['total'].toStringAsFixed(0)}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(top: 2),
                      padding: EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL $_filterCat'.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'KES ${filteredTotal.toStringAsFixed(0)}',
                            style: GoogleFonts.montserrat(
                              color: Color(0xFFFFD60A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _card(String l, String v, String s, bool dark) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white60 : Colors.black45,
            ),
          ),
          SizedBox(height: 6),
          FittedBox(
            child: Text(
              v,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: dark
                    ? const Color.fromARGB(255, 109, 240, 105)
                    : Colors.black,
              ),
            ),
          ),
          Text(
            s,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: dark
                  ? Colors.white38
                  : const Color.fromARGB(115, 255, 0, 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _th(String t, {bool c = false, bool yellow = false}) {
    var txt = Text(
      t,
      style: GoogleFonts.montserrat(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: yellow ? Color(0xFFFFD60A) : Colors.white70,
      ),
    );
    return c ? Center(child: txt) : txt;
  }
}
