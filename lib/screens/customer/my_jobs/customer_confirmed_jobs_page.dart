import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../confirm/client_price_approval_screen.dart';
import '../tracking/customer_tracking_screen.dart';

class CustomerConfirmedJobsPage extends StatefulWidget {
  const CustomerConfirmedJobsPage({
    super.key,
    this.initialJobId,
    this.initialAction,
  });
  final String? initialJobId;
  final String? initialAction;

  @override
  State<CustomerConfirmedJobsPage> createState() =>
      _CustomerConfirmedJobsPageState();
}

class _CustomerConfirmedJobsPageState extends State<CustomerConfirmedJobsPage> {
  String? _highlightedId;
  bool _didAutoNav = false;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.initialJobId;

    // Auto-navigate for deep-link actions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_didAutoNav) return;
      if (widget.initialJobId == null) return;

      if (widget.initialAction == 'new_price') {
        _didAutoNav = true;
        // Will be handled after we fetch job data in builder via flag, but keep as fallback
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirmed Jobs',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .where('customerId', isEqualTo: uid)
            .where(
              'status',
              whereIn: [
                'assigned',
                'confirmed',
                'travelling',
                'site_visit',
                'in_progress',
                'pending_completion',
                'job_completed',
              ],
            )
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var docs = snap.data!.docs.toList();

          // Bring initialJobId to top
          if (widget.initialJobId != null) {
            docs.sort((a, b) {
              if (a.id == widget.initialJobId) return -1;
              if (b.id == widget.initialJobId) return 1;
              return 0;
            });
          }

          if (docs.isEmpty) {
            return Center(
              child: Text('No confirmed jobs', style: GoogleFonts.inter()),
            );
          }

          // Auto-open price approval if banner tapped on new_price
          if (!_didAutoNav &&
              widget.initialAction == 'new_price' &&
              widget.initialJobId != null) {
            final idx = docs.indexWhere((d) => d.id == widget.initialJobId);
            if (idx != -1) {
              final job = docs[idx].data() as Map<String, dynamic>;
              _didAutoNav = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientPriceApprovalScreen(
                      jobId: widget.initialJobId!,
                      job: job,
                    ),
                  ),
                );
              });
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              var doc = docs[i];
              var job = doc.data() as Map<String, dynamic>;
              var jobId = doc.id;
              var reneg = job['renegotiation'] as Map<String, dynamic>?;
              double agreed = (job['agreedPrice'] ?? job['budget'] ?? 0)
                  .toDouble();
              bool isHighlighted = jobId == _highlightedId;

              // Determine current phase for banner inside card
              String phase = '';
              if (job['travelling'] == true ||
                  job['siteVisitStarted'] == true ||
                  job['status'] == 'travelling') {
                phase = 'travelling';
              } else if (job['siteVisitDone'] == true &&
                  job['status'] == 'site_visit') {
                phase = 'site_visited';
              } else if (reneg != null &&
                  reneg['requested'] == true &&
                  reneg['status'] == 'pending') {
                phase = 'new_price';
              } else if (reneg != null &&
                  reneg['currentPhase'] == 'parts_confirmed_by_fundi') {
                phase = 'parts_confirmed';
              } else if (reneg != null &&
                      reneg['currentPhase'] == 'fundi_working' ||
                  job['status'] == 'in_progress') {
                phase = 'working';
              } else if (reneg != null &&
                      reneg['currentPhase'] == 'completed_by_fundi' ||
                  job['status'] == 'job_completed' ||
                  job['status'] == 'pending_completion') {
                phase = 'completed';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isHighlighted
                      ? const BorderSide(
                          color: FundipapColors.primaryYellow,
                          width: 2,
                        )
                      : BorderSide.none,
                ),
                color: isHighlighted ? Colors.yellow.shade50 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              job['title'] ?? '',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isHighlighted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: FundipapColors.primaryYellow,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'FOCUS',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        'KES $agreed • ${job['status']} • Escrow: ${job['escrowStatus'] ?? 'pending'}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      const SizedBox(height: 8),

                      // PHASE BANNERS - this is what the banner tap should show
                      if (phase == 'travelling')
                        _phaseTile(
                          Icons.directions_bike,
                          Colors.blue.shade50,
                          'Fundi is travelling',
                          '${job['assignedFundiName'] ?? 'Fundi'} is on the way',
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CustomerTrackingScreen(
                                  jobId: jobId,
                                  job: job,
                                ),
                              ),
                            );
                          },
                        ),
                      if (phase == 'site_visited')
                        _phaseTile(
                          Icons.location_on,
                          Colors.blue.shade50,
                          'Fundi visited site',
                          '${job['assignedFundiName'] ?? 'Fundi'} visited • Waiting for quote',
                          null,
                        ),
                      if (phase == 'parts_confirmed')
                        _phaseTile(
                          Icons.check_circle,
                          Colors.green.shade50,
                          'Fundi confirmed parts',
                          'Parts available • ${job['title']}',
                          null,
                        ),
                      if (phase == 'working')
                        _phaseTile(
                          Icons.build,
                          Colors.green.shade50,
                          'Fundi is working',
                          '${job['assignedFundiName'] ?? 'Fundi'} working on ${job['title']}',
                          null,
                        ),
                      if (phase == 'completed')
                        _phaseTile(
                          Icons.verified,
                          Colors.green.shade100,
                          'Fundi completed job',
                          '${job['title']} • Review & release',
                          () {
                            // TODO: push to your completion review screen
                          },
                        ),

                      if (reneg != null &&
                          reneg['requested'] == true &&
                          reneg['status'] != 'accepted') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fundi requests new price after visit',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Reason: ${reneg['reason'] ?? ''}',
                                style: GoogleFonts.inter(fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Extra KES ${reneg['extraLabor'] ?? 0} • Total labor KES ${reneg['newLaborTotal'] ?? reneg['newPrice']}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClientPriceApprovalScreen(
                                        jobId: jobId,
                                        job: job,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'REVIEW BREAKDOWN & PHOTOS',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _phaseTile(
    IconData icon,
    Color bg,
    String title,
    String body,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: FundipapColors.primaryYellow.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 16),
          ],
        ),
      ),
    );
  }
}
