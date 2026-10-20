import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DisputesTab extends StatelessWidget {
  const DisputesTab({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('disputes')
          .where('status', isEqualTo: 'open')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty)
          return Center(child: Text('No open disputes ✓'));
        return ListView(
          padding: EdgeInsets.all(8),
          children: snap.data!.docs.map((doc) {
            var d = doc.data() as Map<String, dynamic>;
            String role = d['reporterRole'] ?? 'unknown';
            return Card(
              child: ListTile(
                title: Text(
                  '${d['jobTitle'] ?? ''} • ${d['type'] ?? ''} • by ${role.toUpperCase()}',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(d['jobId'])
                            .update({
                              'status': 'cancelled',
                              'escrowStatus': 'refunded',
                            });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await doc.reference.update({
                          'status': 'resolved_fundi_win',
                          'resolvedAt': FieldValue.serverTimestamp(),
                        });
                        await FirebaseFirestore.instance
                            .collection('jobs')
                            .doc(d['jobId'])
                            .update({'status': 'completed'});
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
  }
}
