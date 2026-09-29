import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class FundiRejectedTab extends StatelessWidget {
  final Stream<QuerySnapshot> bidsStream;
  const FundiRejectedTab({super.key, required this.bidsStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: bidsStream,
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(child: SelectableText('Error: ${snap.error}'));
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
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
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
                      Text(
                        'Reason: ${bid['rejectionCategory'] ?? ''} ${bid['rejectionReason'] ?? ''}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
