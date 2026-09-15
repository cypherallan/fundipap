import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ClientCompletedTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Future<void> Function(BuildContext, String, Map<String, dynamic>)
  onRate;
  const ClientCompletedTab({
    super.key,
    required this.docs,
    required this.onRate,
  });
  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          'No completed jobs yet',
          style: GoogleFonts.inter(color: Colors.black45),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        var d = docs[i].data() as Map<String, dynamic>;
        var jobId = docs[i].id;
        bool alreadyRated = d['clientRated'] == true;
        return Card(
          child: ListTile(
            title: Text(d['title'] ?? ''),
            subtitle: Text(
              'KES ${d['agreedPrice'] ?? d['budget']} • ${d['assignedFundiName'] ?? 'Fundi'}',
            ),
            trailing: alreadyRated
                ? const Icon(Icons.check_circle, color: Colors.green)
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FundipapColors.primaryYellow,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => onRate(context, jobId, d),
                    child: Text(
                      'Rate',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
