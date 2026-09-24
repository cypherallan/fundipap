import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/fundi_request_new_price.dart';
import 'fundi_visit_customer_tab.dart';
import '../../../widgets/animated_waiting_card.dart'; // <-- you imported correctly

class FundiCustomerTimelinePage extends StatelessWidget {
  final String jobId;
  final String clientName;
  final String jobTitle;
  const FundiCustomerTimelinePage({
    super.key,
    required this.jobId,
    required this.clientName,
    required this.jobTitle,
  });

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  Future<void> _startSiteVisit(BuildContext context) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VisitCustomerScreen(jobId: jobId, job: {'title': jobTitle}),
      ),
    );
  }

  Future<void> _confirmPartsAvailable() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation.currentPhase': 'parts_confirmed_by_fundi',
      'renegotiation.partsConfirmedByFundi': true,
      'renegotiation.partsConfirmedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _startJob() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'renegotiation.currentPhase': 'fundi_working',
      'workStartedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _completeJob() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'job_completed',
      'renegotiation.currentPhase': 'completed_by_fundi',
      'completedAt': FieldValue.serverTimestamp(),
      'customerHasUnread': true,
      'fundiHasUnread': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        var job = snap.data!.data() as Map<String, dynamic>;
        var status = (job['status'] ?? '').toString();
        var escrow = (job['escrowStatus'] ?? 'pending').toString();
        bool escrowDone = escrow == 'held' || escrow == 'paid';
        int agreedPrice = _toInt(
          job['agreedPrice'] ??
              job['acceptedBidAmount'] ??
              job['fundiBidAmount'] ??
              job['budget'] ??
              0,
        );
        var reneg = job['renegotiation'] as Map<String, dynamic>?;
        String phase = (reneg?['currentPhase'] ?? '').toString();
        String rs = (reneg?['status'] ?? '').toString();
        bool siteDone =
            job['siteVisitDone'] == true || job['siteVisited'] == true;
        bool travelling = job['travelling'] == true || status == 'travelling';
        bool extraPaid = (job['extraEscrowStatus'] ?? '') == 'paid';
        int extraAmt = _toInt(
          job['extraLaborAmount'] ?? reneg?['extraLabor'] ?? 0,
        );
        List parts = List.from(reneg?['partsNeeded'] ?? []);

        List<Widget> timeline = [];

        // RULE 1: FUNDI WAITING FOR CLIENT TO PAY ESCROW - ANIMATED ORANGE
        if (!escrowDone) {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to pay KES $agreedPrice to escrow',
              message:
                  'Client $clientName has confirmed you but has NOT locked money yet. You cannot start site visit until escrow is held. You will be notified.',
            ),
          );
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.check_circle,
              iconColor: Colors.green,
              title: 'Bid accepted - Done',
              message: 'Done',
              time: 'Earlier',
              isDone: true,
            ),
          );
          return Scaffold(
            appBar: AppBar(
              title: Text(
                clientName,
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              backgroundColor: FundipapColors.blackGray,
              foregroundColor: Colors.white,
            ),
            body: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: timeline.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => timeline[i],
            ),
          );
        }

        // RULE 2: OTHER FUNDI WAITING FOR CLIENT ACTIONS - ALSO ORANGE ANIMATED
        if (phase == 'waiting_for_client_to_buy_parts') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to buy materials',
              message:
                  'Client locked KES $extraAmt. Waiting for ${parts.length} items: ${parts.join(", ")}. You will be notified when they confirm.',
            ),
          );
        } else if (phase == 'client_claims_parts_bought') {
          timeline.add(
            _card(
              color: Colors.blue.shade50,
              border: Colors.blue,
              icon: Icons.inventory,
              iconColor: Colors.blue.shade800,
              title: 'Client says materials bought',
              message: 'Confirm to show START WORK',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _confirmPartsAvailable,
                child: const Text(
                  'CONFIRM MATERIALS AVAILABLE',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        } else if (rs.contains('pending_extra_escrow')) {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to lock extra KES $extraAmt',
              message:
                  'You requested price review. Client accepted but must lock extra KES $extraAmt before you continue. Waiting for client.',
            ),
          );
        } else if (rs == 'pending' || rs == 'countered_by_fundi') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Waiting for client to confirm price review',
              message:
                  'You sent new price breakdown. Waiting for $clientName to review and accept. You will be notified.',
            ),
          );
        } else if (phase == 'completed_by_fundi' ||
            status == 'job_completed' ||
            status == 'pending_completion') {
          timeline.add(
            OrangeAnimatedWaitingCard(
              title: 'Job Completed - Waiting for client confirmation',
              message:
                  'You marked $jobTitle as completed. Waiting for $clientName to confirm and release KES $agreedPrice. This is waiting state until client confirms.',
            ),
          );
        } else if (phase == 'parts_confirmed_by_fundi') {
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.check_circle,
              iconColor: Colors.green.shade800,
              title: 'Materials confirmed',
              message: 'Press START WORK to start.',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _startJob,
                child: const Text(
                  'START WORK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        } else if (status == 'in_progress' || phase == 'fundi_working') {
          timeline.add(
            _card(
              color: Colors.orange.shade50,
              border: Colors.orange,
              icon: Icons.construction,
              iconColor: Colors.orange.shade800,
              title: 'You are working',
              message:
                  'You are working on $jobTitle. When done, mark as completed.',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.greenSuccess,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _completeJob,
                child: const Text(
                  'MARK JOB AS COMPLETED',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        } else if (!siteDone && travelling) {
          timeline.add(
            _card(
              color: Colors.blue.shade50,
              border: Colors.blue,
              icon: Icons.directions_bike,
              iconColor: Colors.blue,
              title: 'You are on the way',
              message: 'Travelling to client',
              time: 'Now',
              isCurrent: true,
              action: ElevatedButton.icon(
                icon: const Icon(Icons.navigation),
                label: const Text('OPEN MAP'),
                onPressed: () => _startSiteVisit(context),
              ),
            ),
          );
        } else if (!siteDone) {
          timeline.add(
            _card(
              color: Colors.white,
              border: FundipapColors.blackGray,
              icon: Icons.location_on,
              iconColor: Colors.black,
              title: 'Escrow locked - Start site visit',
              message:
                  'Client paid KES $agreedPrice to escrow. You can now start site visit.',
              time: 'Now',
              isCurrent: true,
              action: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FundipapColors.blackGray,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  icon: const Icon(Icons.navigation),
                  label: const Text('START SITE VISIT'),
                  onPressed: () => _startSiteVisit(context),
                ),
              ),
            ),
          );
        } else if (siteDone &&
            (status == 'site_visit' ||
                status == 'assigned' ||
                status == 'confirmed')) {
          timeline.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FundipapColors.greenSuccess,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next action',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startJob,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.greenSuccess,
                          ),
                          child: const Text(
                            'START JOB',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FundiRequestNewPriceScreen(
                                jobId: jobId,
                                job: job,
                              ),
                            ),
                          ),
                          child: const Text('New Price'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        // DONE CARDS
        timeline.add(
          _card(
            color: Colors.green.shade50,
            border: Colors.green,
            icon: Icons.lock,
            iconColor: Colors.green,
            title: 'Escrow locked - Done KES $agreedPrice',
            message: 'Done',
            time: 'Done',
            isDone: true,
          ),
        );
        if (extraPaid) {
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.lock_open,
              iconColor: Colors.green.shade800,
              title: 'Client locked KES $extraAmt - Done',
              message: 'Done',
              time: 'Done',
              isDone: true,
            ),
          );
        }
        if (siteDone) {
          timeline.add(
            _card(
              color: Colors.green.shade50,
              border: Colors.green,
              icon: Icons.location_on,
              iconColor: Colors.green,
              title: 'Site visited - Done',
              message: 'Done',
              time: 'Done',
              isDone: true,
            ),
          );
        }
        timeline.add(
          _card(
            color: Colors.green.shade50,
            border: Colors.green,
            icon: Icons.check_circle,
            iconColor: Colors.green,
            title: 'Bid accepted - Done',
            message: 'Done',
            time: 'Earlier',
            isDone: true,
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              clientName,
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            backgroundColor: FundipapColors.blackGray,
            foregroundColor: Colors.white,
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: timeline.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => timeline[i],
          ),
        );
      },
    );
  }

  Widget _card({
    required Color color,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String time,
    bool isDone = false,
    bool isCurrent = false,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isCurrent ? 1.5 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: iconColor,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                    if (isDone)
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: GoogleFonts.inter(fontSize: 11)),
                if (action != null) ...[const SizedBox(height: 10), action],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
