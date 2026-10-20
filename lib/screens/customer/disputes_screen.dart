import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});
  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  Widget _buildList(String filter) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    var stream = FirebaseFirestore.instance
        .collection('disputes')
        .where('clientId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        var allDocs = snap.data!.docs.toList();

        // Filter by who raised
        var docs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String role = (data['reporterRole'] ?? 'client').toString();
          if (filter == 'my')
            return role == 'client'; // client raised against fundi
          return role == 'fundi'; // fundi raised against client
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  filter == 'my'
                      ? Icons.outgoing_mail
                      : Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  filter == 'my' ? 'My Disputes' : 'Disputes Against Me',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
                Text(
                  filter == 'my'
                      ? 'You haven\'t raised any'
                      : 'No disputes against you • Clean ✓',
                  style: GoogleFonts.inter(color: Colors.black45),
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
                      'Job ${d['jobId']?.toString().substring(0, 6) ?? ''} • ${d['type'] ?? ''} • ${d['status'] ?? 'open'}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Fundi: ${d['fundiName'] ?? ''} • KES ${d['escrowAmount'] ?? ''}',
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
                onTap: () {},
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
          'Disputes & Tickets',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
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
        children: [_buildList('my'), _buildList('against')],
      ),
    );
  }
}
