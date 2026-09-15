import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fundi_my_jobs_actions.dart';
import 'fundi_my_jobs_pending_tab.dart';
import 'fundi_my_jobs_confirmed_tab.dart';
import 'fundi_my_jobs_rejected_tab.dart';
import 'fundi_my_jobs_completed_tab.dart';

class FundiMyJobsPage extends StatefulWidget {
  const FundiMyJobsPage({super.key});
  @override
  State<FundiMyJobsPage> createState() => _FundiMyJobsPageState();
}

class _FundiMyJobsPageState extends State<FundiMyJobsPage>
    with SingleTickerProviderStateMixin, FundiMyJobsActionsMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var jobsStream = FirebaseFirestore.instance
        .collection('jobs')
        .where('assignedFundi', isEqualTo: uid)
        .snapshots();
    var bidsStream = FirebaseFirestore.instance
        .collectionGroup('bids')
        .where('fundiId', isEqualTo: uid)
        .snapshots();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(
          'My Jobs',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          tabs: const [
            Tab(text: 'PENDING'),
            Tab(text: 'CONFIRMED'),
            Tab(text: 'REJECTED'),
            Tab(text: 'COMPLETED'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          FundiPendingTab(bidsStream: bidsStream, onCounter: counterAsFundi),
          FundiConfirmedTab(
            jobsStream: jobsStream,
            onRequestNewPrice: requestNewPriceAfterVisit,
            onStartJob: startJob,
            onAddParts: addParts,
            onMarkCompleted: markCompletedFundi,
          ),
          FundiRejectedTab(bidsStream: bidsStream),
          FundiCompletedTab(jobsStream: jobsStream),
        ],
      ),
    );
  }
}
