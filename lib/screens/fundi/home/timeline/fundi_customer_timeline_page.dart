import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/job_chat_section.dart';
import '../../../../services/fundi_waiting_state_service.dart';
import '../timeline/fundi_timeline_context.dart';
import 'core/timeline_utils.dart';
import 'core/timeline_navigation.dart';
import 'steps/history_builder.dart';
import 'steps/current_waiting_builder.dart';
import 'steps/completed_released_view.dart';
import '../../../customer/home/timeline/widgets/timeline_cancel_wrapper.dart';

class FundiCustomerTimelinePage extends StatefulWidget {
  final String jobId;
  final String clientName;
  final String jobTitle;
  const FundiCustomerTimelinePage({
    super.key,
    required this.jobId,
    required this.clientName,
    required this.jobTitle,
  });
  @override
  State<FundiCustomerTimelinePage> createState() =>
      _FundiCustomerTimelinePageState();
}

class _FundiCustomerTimelinePageState extends State<FundiCustomerTimelinePage> {
  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, jobSnap) {
        if (!jobSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // FIX: job deleted from Firestore -> show no longer available
        if (!jobSnap.data!.exists || jobSnap.data!.data() == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Fundipap',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 48,
                      color: Colors.black26,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This job is no longer available',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'It may have been deleted by the client',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                      child: Text(
                        'Go Home',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        var job = jobSnap.data!.data() as Map<String, dynamic>;
        var c = FundiTimelineContext.fromSnapshot(
          context: context,
          jobId: widget.jobId,
          clientName: widget.clientName,
          jobTitle: widget.jobTitle,
          job: job,
        );
        var status = c.status.toLowerCase();

        if (c.escrowReleased) {
          if (!c.fundiConfirmedPayment || !c.fundiRatedClient)
            return buildCompletedReleasedView(context, c);
        }
        var escrowStatus = (job['escrowStatus'] ?? 'pending')
            .toString()
            .toLowerCase();
        bool escrowDone = ['held', 'paid', 'released'].contains(escrowStatus);
        int labour = toInt(
          job['laborCost'] ?? job['agreedPrice'] ?? job['price'] ?? 0,
        );
        int transport = toInt(job['transportFee'] ?? 0);
        int fundiSees = labour + transport;
        bool siteDone =
            toBool(job['siteVisitDone']) ||
            toBool(job['siteVisited']) ||
            job['siteVisitedAt'] != null ||
            ['site_visit', 'site_visit_done'].contains(status);
        bool isCancelled = status.contains('cancel');

        if (isCancelled) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => goBack(context, 4),
              ),
              title: Text(
                widget.clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'You cancelled this job',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.jobId)
              .collection('bids')
              .where('fundiId', isEqualTo: uid)
              .snapshots(),
          builder: (context, bidsSnap) {
            if (!bidsSnap.hasData)
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            if (bidsSnap.data!.docs.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => goBack(context, 2),
                  ),
                  title: Text(
                    widget.clientName,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You cancelled this job',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            var bidDoc = bidsSnap.data!.docs.first;
            var bid = bidDoc.data() as Map<String, dynamic>;

            // FIX: open job cancelled by fundi (deletedForFundi) -> show only cancelled
            if (bid['deletedForFundi'] == true ||
                (bid['status'] ?? '').toString() == 'withdrawn' ||
                (bid['status'] ?? '').toString() == 'cancelled') {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => goBack(context, 2),
                  ),
                  title: Text(
                    widget.clientName,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cancel,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You cancelled this job',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            int myBidPrice = toInt(
              bid['price'] ?? bid['amount'] ?? bid['bidPrice'] ?? 0,
            );

            return StreamBuilder<QuerySnapshot>(
              stream: bidDoc.reference
                  .collection('counterOffers')
                  .orderBy('at', descending: false)
                  .snapshots(),
              builder: (context, coSnap) {
                List<DocumentSnapshot> coDocs = coSnap.data?.docs ?? [];
                List<Map<String, dynamic>> priceHistory =
                    (job['priceHistory'] as List?)
                        ?.cast<Map<String, dynamic>>() ??
                    [];
                FundiWaitingState? waitingState = getFundiWaitingState(
                  job: job,
                  bid: bid,
                  counterOffers: coDocs,
                  uid: uid,
                );
                if (siteDone &&
                    waitingState?.type == FundiWaitingType.escrowLocked) {
                  waitingState = FundiWaitingState(
                    type: FundiWaitingType.siteVisited,
                    title: 'Site visited - Done KES $fundiSees',
                    message:
                        'You visited site. Next: START JOB or request new price',
                    price: fundiSees,
                  );
                }

                List<Widget> doneHistory = buildDoneHistory(
                  job: job,
                  coDocs: coDocs,
                  uid: uid,
                  myBidPrice: myBidPrice,
                  priceHistory: priceHistory,
                  waitingState: waitingState,
                  clientName: widget.clientName,
                  jobTitle: widget.jobTitle,
                  labour: labour,
                  transport: transport,
                  fundiSees: fundiSees,
                  escrowDone: escrowDone,
                  siteDone: siteDone,
                  status: status,
                );

                Widget? currentWaiting = buildCurrentWaiting(
                  context: context,
                  job: job,
                  jobId: widget.jobId,
                  jobTitle: widget.jobTitle,
                  clientName: widget.clientName,
                  status: status,
                  fundiSees: fundiSees,
                  bidRef: bidDoc.reference,
                  myBidPrice: myBidPrice,
                  waitingState: waitingState,
                  counterAsFundi: counterAsFundi,
                );

                List<Widget> timeline = [];
                if (currentWaiting != null) timeline.add(currentWaiting);
                timeline.addAll(doneHistory.reversed);

                bool isTravellingNow =
                    job['travelling'] == true || status == 'travelling';
                bool isStartedNow = [
                  'in_progress',
                  'pending_completion',
                  'job_completed',
                ].contains(status);
                bool canFundiCancelNow =
                    !isTravellingNow &&
                    !siteDone &&
                    !isStartedNow &&
                    !status.contains('cancel');

                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => goBack(context, 2),
                    ),
                    title: Text(
                      widget.clientName,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: FundipapColors.blackGray,
                    foregroundColor: Colors.white,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (_) => DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.85,
                              minChildSize: 0.5,
                              maxChildSize: 0.95,
                              builder: (context, scrollCtrl) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(
                                    context,
                                  ).viewInsets.bottom,
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Chat with ${widget.clientName}',
                                      style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Divider(),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: scrollCtrl,
                                        padding: const EdgeInsets.all(12),
                                        child: JobChatSection(
                                          jobId: widget.jobId,
                                          isClient: false,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  body: TimelineCancelWrapper(
                    canCancel: canFundiCancelNow,
                    jobId: widget.jobId,
                    job: job,
                    isClient: false,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: timeline.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => timeline[i],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
