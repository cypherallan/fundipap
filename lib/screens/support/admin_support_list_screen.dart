import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminSupportListScreen extends StatelessWidget {
  const AdminSupportListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Support Escalations',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('supportEscalations')
            .orderBy('escalatedAt', descending: true)
            .snapshots(),
        builder: (c, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator());
          var docs = snap.data!.docs;
          if (docs.isEmpty) return Center(child: Text('No escalations'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              var d = docs[i].data();
              var id = docs[i].id;
              return ListTile(
                title: Text(
                  d['jobTitle'] ?? id,
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                subtitle: Text(
                  '${d['fundiEmail']} • says KES ${d['amountFundiSaysReceived']} vs ${d['finalAmount']} • ${d['status']}',
                  style: GoogleFonts.inter(fontSize: 11),
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminSupportDetailScreen(jobId: id, data: d),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminSupportDetailScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> data;
  const AdminSupportDetailScreen({
    super.key,
    required this.jobId,
    required this.data,
  });
  @override
  State<AdminSupportDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<AdminSupportDetailScreen> {
  final _reply = TextEditingController();
  @override
  Widget build(BuildContext context) {
    var mpesa = (widget.data['mpesa_statement'] as List?) ?? [];
    var shots = (widget.data['screenshots'] as List?) ?? [];
    var ids = (widget.data['id_docs'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobId, style: GoogleFonts.montserrat(fontSize: 12)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            widget.data['description'] ?? '',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          SizedBox(height: 12),
          ...[...mpesa, ...shots, ...ids].map(
            (e) => ListTile(
              title: Text(
                e['name'] ?? 'file',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(Icons.open_in_new),
                onPressed: () => launchUrl(
                  Uri.parse(e['url']),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _reply,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reply to fundi',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              var fundiEmail = widget.data['fundiEmail'];
              await FirebaseFirestore.instance
                  .collection('supportEscalations')
                  .doc(widget.jobId)
                  .collection('replies')
                  .add({
                    'message': _reply.text,
                    'by': 'admin',
                    'adminEmail': FirebaseAuth.instance.currentUser!.email,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              await FirebaseFirestore.instance.collection('mail').add({
                'to': [fundiEmail],
                'message': {
                  'subject': 'Support reply for ${widget.jobId}',
                  'html':
                      '<p>${_reply.text}</p><p>Job: ${widget.data['jobTitle']}</p>',
                },
              });
              await FirebaseFirestore.instance
                  .collection('supportEscalations')
                  .doc(widget.jobId)
                  .update({
                    'status': 'replied',
                    'lastReplyAt': FieldValue.serverTimestamp(),
                  });
              if (mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Replied + emailed')));
            },
            child: Text('REPLY & EMAIL FUNDI'),
          ),
          SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('supportEscalations')
                  .doc(widget.jobId)
                  .update({'status': 'resolved'});
              await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(widget.jobId)
                  .update({'lastDisputeStatus': 'resolved_explained'});
              if (mounted) Navigator.pop(context);
            },
            child: Text('MARK RESOLVED'),
          ),
        ],
      ),
    );
  }
}
