import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FundiMyJobsPage extends StatefulWidget {
  const FundiMyJobsPage({super.key});
  @override
  State<FundiMyJobsPage> createState() => _FundiMyJobsPageState();
}

class _FundiMyJobsPageState extends State<FundiMyJobsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          'My Jobs',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tab,
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          tabs: const [
            Tab(text: 'CONFIRMED'),
            Tab(text: 'REJECTED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // CONFIRMED JOBS - FIXED: no composite index needed
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where('assignedFundi', isEqualTo: uid)
                .snapshots(),
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'Error: ${snap.error}',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              // filter in app
              var docs = snap.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return [
                  'assigned',
                  'in_progress',
                  'completed',
                ].contains(data['status']);
              }).toList();

              docs.sort((a, b) {
                var da = (a.data() as Map<String, dynamic>)['updatedAt'];
                var db = (b.data() as Map<String, dynamic>)['updatedAt'];
                DateTime ta = da is Timestamp ? da.toDate() : DateTime.now();
                DateTime tb = db is Timestamp ? db.toDate() : DateTime.now();
                return tb.compareTo(ta);
              });

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No confirmed jobs yet',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) {
                  var job = docs[i].data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FundipapColors.greenSuccess),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: FundipapColors.greenSuccess,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                job['status'].toString().toUpperCase(),
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'KES ${job['agreedPrice'] ?? job['budget']}',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          job['title'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          job['location'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Client: ${job['customerName'] ?? job['clientName'] ?? 'Client'}',
                              style: GoogleFonts.inter(fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // REJECTED BIDS - NO INDEX VERSION
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('bids')
                .where('fundiId', isEqualTo: uid)
                .snapshots(),
            builder: (_, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      'Error: ${snap.error}',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var filtered = snap.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                return data['status'] == 'rejected' &&
                    data['deletedForFundi'] != true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'No rejected offers',
                    style: GoogleFonts.inter(color: Colors.black45),
                  ),
                );
              }
              return ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) {
                  var bid = filtered[i].data() as Map<String, dynamic>;
                  var jobRef = filtered[i].reference.parent.parent;
                  return FutureBuilder<DocumentSnapshot>(
                    future: jobRef!.get(),
                    builder: (_, jobSnap) {
                      var job = jobSnap.data?.data() as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: FundipapColors.redAlert),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.block,
                                  size: 14,
                                  color: FundipapColors.redAlert,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'REJECTED • KES ${bid['price']}',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: FundipapColors.redAlert,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 16),
                                  onPressed: () async {
                                    await filtered[i].reference.update({
                                      'deletedForFundi': true,
                                    });
                                  },
                                ),
                              ],
                            ),
                            Text(
                              job?['title'] ?? 'Job',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reason: ${bid['rejectionCategory'] ?? ''}',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    bid['rejectionReason'] ?? '',
                                    style: GoogleFonts.inter(fontSize: 11),
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
              );
            },
          ),
        ],
      ),
    );
  }
}
