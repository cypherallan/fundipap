/*import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';

class FundiMonitorTable extends StatelessWidget {
  const FundiMonitorTable({super.key});

  // flexible getter - checks your possible field names for extra amount
  double _getExtra(Map<String, dynamic> data) {
    return (data['extraAmount'] ??
            data['extraCost'] ??
            data['additionalAmount'] ??
            data['partsCost'] ??
            0)
        .toDouble();
  }

  bool _hasPartsRequest(Map<String, dynamic> data) {
    // true if fundi asked client to buy parts / added extra
    if (data['partsRequested'] == true) return true;
    if (data['materialsByClient'] == true) return true;
    if (_getExtra(data) > 0) return true;
    if (data['status'] == 'parts_requested') return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fundi Parts Request Monitoring',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'RED >70% parts request = fundi avoids buying, pushes to client. GREEN <30% = good fundi who buys parts.',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 16),
        // Listen to jobs once, calculate stats locally - 1 query not N queries
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
          builder: (context, jobsSnap) {
            if (!jobsSnap.hasData)
              return Center(child: CircularProgressIndicator());

            // fundiId -> {name, total, partsCount, extraTotal}
            final Map<String, Map<String, dynamic>> stats = {};

            for (var doc in jobsSnap.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              var fundiId = data['fundiId'] ?? data['assignedFundiId'];
              if (fundiId == null) continue;
              var fundiName =
                  data['fundiName'] ??
                  data['assignedFundiName'] ??
                  'Fundi ${fundiId.toString().substring(0, 4)}';

              stats.putIfAbsent(
                fundiId,
                () => {
                  'name': fundiName,
                  'total': 0,
                  'partsCount': 0,
                  'extraTotal': 0.0,
                  'extraJobs': 0,
                },
              );

              stats[fundiId]!['total']++;
              stats[fundiId]!['name'] = fundiName; // update name if we have it

              if (_hasPartsRequest(data)) {
                stats[fundiId]!['partsCount']++;
              }
              double extra = _getExtra(data);
              if (extra > 0) {
                stats[fundiId]!['extraTotal'] += extra;
                stats[fundiId]!['extraJobs']++;
              }
            }

            // Stream fundi names from fundis collection to get real names
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fundis')
                  .snapshots(),
              builder: (context, fundiSnap) {
                if (fundiSnap.hasData) {
                  for (var f in fundiSnap.data!.docs) {
                    var d = f.data() as Map<String, dynamic>;
                    if (stats.containsKey(f.id)) {
                      stats[f.id]!['name'] =
                          d['name'] ?? d['fullName'] ?? stats[f.id]!['name'];
                    }
                  }
                }

                if (stats.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('No jobs data yet', style: GoogleFonts.inter()),
                  );
                }

                var list = stats.values.toList();
                // sort by worst rate first
                list.sort(
                  (a, b) => (b['partsCount'] / b['total']).compareTo(
                    a['partsCount'] / a['total'],
                  ),
                );

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FundipapColors.blackGray,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'FUNDI',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'PARTS REQ RATE',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'EXTRA AVG',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'STATUS',
                                style: GoogleFonts.montserrat(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...list.map((f) {
                        int total = f['total'] as int;
                        int parts = f['partsCount'] as int;
                        int rate = total == 0
                            ? 0
                            : ((parts / total) * 100).round();
                        double avg = f['extraJobs'] > 0
                            ? f['extraTotal'] / f['extraJobs']
                            : 0;

                        Color statusColor = rate > 70
                            ? FundipapColors.redAlert
                            : (rate < 30
                                  ? FundipapColors.greenSuccess
                                  : FundipapColors.primaryYellow);
                        String statusText = rate > 70
                            ? 'RED >70%'
                            : (rate < 30 ? 'GREEN <30%' : 'YELLOW');

                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.black12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  f['name'],
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$rate% ($parts/$total)',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'KES ${avg.round()}',
                                  style: GoogleFonts.inter(fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}*/
