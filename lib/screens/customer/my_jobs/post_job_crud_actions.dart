import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../post_new_job_screen.dart';

mixin PostJobCrudActionsMixin<T extends StatefulWidget> on State<T> {
  Future<void> deleteJob(BuildContext context, String jobId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Delete Job?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove it completely.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FundipapColors.redAlert,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    var bids = await FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .collection('bids')
        .get();
    for (var b in bids.docs) {
      await b.reference.delete();
    }
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).delete();
  }

  Future<void> editJob(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostNewJobScreen(jobId: jobId, existingJob: job),
      ),
    );
  }
}
