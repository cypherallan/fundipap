import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FundiDisputesScreen extends StatefulWidget {
  const FundiDisputesScreen({super.key});
  @override
  State<FundiDisputesScreen> createState() => _FundiDisputesScreenState();
}

class _FundiDisputesScreenState extends State<FundiDisputesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  Widget _buildDisputeList(String filter) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    var stream = FirebaseFirestore.instance
        .collection('disputes')
        .where('fundiId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
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

        var allDocs = snap.data!.docs.toList();

        var docs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String role = (data['reporterRole'] ?? 'fundi').toString();
          if (filter == 'my') {
            return role ==
                'fundi';
          } 
          return role == 'client';
        }).toList();

        docs.sort((a, b) {
          var ad = (a.data() as Map)['createdAt'];
          var bd = (b.data() as Map)['createdAt'];
          if (ad == null || bd == null) return 0;
          return (bd as Timestamp).compareTo(ad as Timestamp);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filter == 'my'
                      ? Icons.outgoing_mail
                      : Icons.warning_amber_rounded,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  filter == 'my'
                      ? 'No disputes raised by you'
                      : 'No disputes against you • Clean ✓',
                  style: GoogleFonts.inter(),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            var d = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  d['reason'] ?? 'Dispute',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job ${d['jobId']?.toString().substring(0, 6) ?? ''} • ${d['type'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${d['jobTitle'] ?? ''} • KES ${d['escrowAmount'] ?? ''}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    d['status'] ?? 'open',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Disputes',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tab,
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          tabs: const [
            Tab(text: 'MY DISPUTES'),
            Tab(text: 'AGAINST ME'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildDisputeList('my'), _buildDisputeList('against')],
      ),
    );
  }
}
