import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../my_jobs/fundi_request_new_price.dart';
import 'fundi_visit_customer_tab.dart';

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

  void _openNewPrice(BuildContext context, Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundiRequestNewPriceScreen(jobId: jobId, job: job),
      ),
    );
  }

  Future<void> _startJob() async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'workStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          clientName,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        backgroundColor: FundipapColors.blackGray,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          var job = snap.data!.data() as Map<String, dynamic>;
          var escrow = (job['escrowStatus'] ?? 'pending').toString();
          var status = (job['status'] ?? '').toString();
          bool siteDone = job['siteVisitDone'] == true;
          bool travelling = job['travelling'] == true || status == 'travelling';
          double amount =
              ((job['escrowAmount'] ?? job['agreedPrice'] ?? job['budget'] ?? 0)
                      as num)
                  .toDouble();
          var reneg = job['renegotiation'] as Map<String, dynamic>?;
          bool locked =
              escrow == 'held' || escrow == 'paid' || escrow == 'locked';

          List<Widget> timeline = [];

          if (!locked) {
            timeline.add(
              _card(
                color: Colors.orange.shade50,
                border: Colors.orange,
                icon: Icons.hourglass_top,
                iconColor: Colors.orange.shade800,
                title: 'Bid accepted',
                message: 'Waiting for $clientName to pay KES ${amount.toInt()}',
                time: 'Now',
                isCurrent: true,
              ),
            );
          } else {
            timeline.add(
              _card(
                color: Colors.green.shade50,
                border: Colors.green,
                icon: Icons.check_circle,
                iconColor: Colors.green,
                title: 'Bid accepted',
                message: 'Bid accepted by $clientName',
                time: 'Earlier',
                isDone: true,
              ),
            );
            timeline.add(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card(
                    color: Colors.green.shade50,
                    border: Colors.green,
                    icon: Icons.lock_open,
                    iconColor: Colors.green.shade800,
                    title: 'Client paid for the service',
                    message:
                        'KES ${amount.toInt()} locked in escrow. Money will be released once job is marked completed by client.',
                    time: 'Now',
                    isCurrent: status == 'assigned' || status == 'confirmed',
                  ),
                  if ((status == 'assigned' || status == 'confirmed') &&
                      !travelling &&
                      !siteDone) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.blackGray,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        icon: const Icon(Icons.navigation),
                        label: const Text(
                          'Start Site Visit - Must Visit First',
                        ),
                        onPressed: () => _startSiteVisit(context),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          if (reneg != null && reneg['requested'] == true) {
            String rs = (reneg['status'] ?? 'pending').toString();
            if (rs == 'pending') {
              timeline.add(
                _card(
                  color: Colors.orange.shade50,
                  border: Colors.orange,
                  icon: Icons.pending_actions,
                  iconColor: Colors.orange.shade800,
                  title: 'Waiting for client to confirm price review',
                  message:
                      'You requested Labor KES ${reneg['newLaborTotal']} + Parts KES ${reneg['partsEstimateTotal']}. Waiting for $clientName to accept/counter.',
                  time: 'Now',
                  isCurrent: true,
                ),
              );
            } else if (rs == 'countered_by_client') {
              timeline.add(
                _card(
                  color: Colors.blue.shade50,
                  border: Colors.blue,
                  icon: Icons.reply,
                  iconColor: Colors.blue,
                  title: 'Client countered your price',
                  message:
                      'Client countered to KES ${reneg['counterOffer'] ?? reneg['newLaborTotal']}. Review and accept.',
                  time: 'Now',
                  isCurrent: true,
                ),
              );
            } else if (rs.contains('accepted')) {
              timeline.add(
                _card(
                  color: Colors.green.shade50,
                  border: Colors.green,
                  icon: Icons.verified,
                  iconColor: Colors.green,
                  title: 'Price review accepted',
                  message:
                      'Client accepted KES ${reneg['newLaborTotal']}. You can now start job.',
                  time: 'Done',
                  isDone: true,
                ),
              );
            }
          }

          if (travelling && !siteDone)
            timeline.add(
              _card(
                color: Colors.blue.shade50,
                border: Colors.blue,
                icon: Icons.directions_bike,
                iconColor: Colors.blue,
                title: 'You are on the way',
                message: 'Travelling to $clientName location',
                time: 'Now',
                isCurrent: true,
              ),
            );
          if (siteDone)
            timeline.add(
              _card(
                color: Colors.green.shade50,
                border: Colors.green,
                icon: Icons.location_on,
                iconColor: Colors.green,
                title: 'Site visited',
                message: 'You visited $clientName site for $jobTitle',
                time: 'Done',
                isDone: true,
              ),
            );

          if (siteDone &&
              status == 'site_visit' &&
              (reneg == null || reneg['requested'] != true)) {
            timeline.add(
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FundipapColors.greenSuccess,
                    width: 1.2,
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
                    const SizedBox(height: 8),
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
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openNewPrice(context, job),
                            child: const Text('Request New Price'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          if (status == 'in_progress')
            timeline.add(
              _card(
                color: Colors.green.shade50,
                border: Colors.green,
                icon: Icons.construction,
                iconColor: Colors.green.shade800,
                title: 'Working',
                message: 'Working on $jobTitle for $clientName',
                time: 'Now',
                isCurrent: true,
              ),
            );

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: FundipapColors.blackGray,
                      child: Text(
                        clientName.isNotEmpty
                            ? clientName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          jobTitle,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: timeline.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => timeline[i],
                ),
              ),
            ],
          );
        },
      ),
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
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.black87),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: border.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Current',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
