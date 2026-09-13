import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../post_new_job_screen.dart';
import 'post_job_crud_actions.dart';
import 'post_job_bidding_actions.dart';
import 'post_job_escrow_actions.dart';
import 'post_job_pending_tab.dart';
import 'post_job_confirmed_tab.dart';
import 'post_job_rejected_tab.dart';
import 'post_job_completed_tab.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});
  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen>
    with
        PostJobCrudActionsMixin<PostJobScreen>,
        PostJobBiddingActionsMixin<PostJobScreen>,
        PostJobEscrowActionsMixin<PostJobScreen> {
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelColor: Colors.black,
              indicatorColor: FundipapColors.primaryYellow,
              labelStyle: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Rejected'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostNewJobScreen()),
                ),
                icon: const Icon(Icons.add, color: Colors.black),
                label: Text(
                  'Post New Job',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText('Error: ${snap.error}'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var allDocs = snap.data!.docs;
                return TabBarView(
                  children: [
                    ClientPendingTab(
                      jobs: allDocs
                          .where(
                            (d) => [
                              'open',
                              'bidding',
                              'negotiating',
                            ].contains((d.data() as Map)['status']),
                          )
                          .toList(),
                      onCounter: counterBid,
                      onAccept: acceptBid,
                      onEdit: editJob,
                      onDelete: deleteJob,
                    ),
                    ClientConfirmedTab(
                      docs: allDocs
                          .where(
                            (d) => [
                              'assigned',
                              'site_visit',
                              'in_progress',
                              'pending_completion',
                            ].contains((d.data() as Map)['status']),
                          )
                          .toList(),
                      onCounter: handleCounterBid,
                      onAcceptReneg: acceptRenegotiation,
                      onPayEscrow: payEscrowSimulated,
                      onConfirmCompletion: confirmCompletionClient,
                    ),
                    ClientRejectedTab(allJobDocs: allDocs),
                    ClientCompletedTab(
                      docs: allDocs
                          .where(
                            (d) => (d.data() as Map)['status'] == 'completed',
                          )
                          .toList(),
                      onRate: showClientRateFundiDialog,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
