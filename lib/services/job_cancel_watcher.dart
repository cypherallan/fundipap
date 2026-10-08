import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

mixin JobCancelWatcher<T extends StatefulWidget> on State<T> {
  StreamSubscription? _jobCancelSub;
  StreamSubscription? _bidCancelSub;
  bool _cancelHandled = false;

  void watchCancellation({
    required String jobId,
    String? bidId,
    required BuildContext context,
  }) {
    _jobCancelSub = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .snapshots()
        .listen((doc) {
          if (!doc.exists || _cancelHandled) return;
          var d = doc.data();
          if (d == null) return;
          bool cancelled =
              d['cancelled'] == true ||
              d['autoCancelled'] == true ||
              (d['status'] ?? '').toString().toLowerCase().contains('cancel');
          if (cancelled) _showCancelledAndClose(context, d);
        });

    if (bidId != null) {
      _bidCancelSub = FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .collection('bids')
          .doc(bidId)
          .snapshots()
          .listen((doc) {
            if (!doc.exists || _cancelHandled) return;
            var d = doc.data();
            if (d == null) return;
            String st = (d['status'] ?? '').toString().toLowerCase();
            if (st.contains('cancel') || st == 'withdrawn' || st == 'deleted') {
              _showCancelledAndClose(context, d, isBidOnly: true);
            }
          });
    }
  }

  void _showCancelledAndClose(
    BuildContext context,
    Map<String, dynamic> data, {
    bool isBidOnly = false,
  }) {
    if (_cancelHandled) return;
    _cancelHandled = true;
    _jobCancelSub?.cancel();
    _bidCancelSub?.cancel();
    if (!mounted) return;

    String reason = (data['fundiCancelReason'] ?? data['cancelReason'] ?? '')
        .toString();
    String title = isBidOnly
        ? 'Fundi withdrew bid'
        : 'Fundi cancelled this job';
    String msg = isBidOnly
        ? 'This fundi withdrew his bid for this job.'
        : 'Fundi cancelled this job${reason.isNotEmpty ? ': $reason' : ''}.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        content: Text(msg, style: GoogleFonts.inter(fontSize: 12)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).popUntil((r) => r.isFirst); // back to home
            },
            child: Text(
              'OK',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _jobCancelSub?.cancel();
    _bidCancelSub?.cancel();
    super.dispose();
  }
}
