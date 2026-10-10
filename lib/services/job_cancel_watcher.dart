import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

            // FIX: client removed fundi before escrow
            if (st == 'cancelled_by_client') {
              _showCancelledAndClose(
                context,
                {
                  ...d,
                  'cancelledBy': 'client',
                  'cancelReason':
                      d['cancelReason'] ?? 'Cancelled before escrow',
                },
                isBidOnly: false, // show as client cancelled, not withdrawn
              );
              return;
            }

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

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    String cancelledBy = (data['cancelledBy'] ?? '').toString().toLowerCase();
    bool autoCancelled = data['autoCancelled'] == true;
    String reason = (data['fundiCancelReason'] ?? data['cancelReason'] ?? '')
        .toString();

    String clientId = (data['customerId'] ?? data['clientId'] ?? '').toString();
    String fundiId =
        (data['assignedFundi'] ??
                data['assignedFundiId'] ??
                data['fundiId'] ??
                '')
            .toString();
    // if bid doc, fundiId is in data itself
    if (fundiId.isEmpty) fundiId = (data['fundiId'] ?? '').toString();

    bool viewerIsClient = clientId.isNotEmpty
        ? clientId == uid
        : cancelledBy != 'client'
        ? true
        : false;
    // fallback: if we can't tell from ids, use cancelledBy logic with uid vs fundiId
    if (clientId.isEmpty && fundiId.isNotEmpty) {
      viewerIsClient = fundiId != uid;
    }

    String title;
    String msg;

    if (isBidOnly) {
      if (viewerIsClient) {
        title = 'Fundi withdrew bid';
        msg = 'This fundi withdrew his bid for this job.';
      } else {
        title = 'You withdrew your bid';
        msg = 'You withdrew your bid.';
      }
    } else if (autoCancelled || cancelledBy == 'system') {
      title = 'Job auto-cancelled';
      msg = reason.isNotEmpty
          ? 'This job was auto-cancelled: $reason'
          : 'This job was auto-cancelled.';
    } else if (cancelledBy == 'client') {
      if (viewerIsClient) {
        title = 'You cancelled this job';
        msg = reason.isNotEmpty && reason != 'Cancelled before escrow'
            ? 'You cancelled: $reason'
            : 'You cancelled this job before escrow. No fee charged.';
      } else {
        title = 'Client cancelled this job';
        msg = reason.isNotEmpty && reason != 'Cancelled before escrow'
            ? 'Client cancelled: $reason'
            : 'Client cancelled this job before escrow.';
      }
    } else {
      // fundi cancelled
      if (viewerIsClient) {
        title = 'Fundi cancelled this job';
        msg =
            'Fundi cancelled this job${reason.isNotEmpty ? ': $reason' : ''}.';
      } else {
        title = 'You cancelled this job';
        msg = reason.isNotEmpty
            ? 'You cancelled: $reason'
            : 'You cancelled this job.';
      }
    }

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
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((r) => r.isFirst);
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
