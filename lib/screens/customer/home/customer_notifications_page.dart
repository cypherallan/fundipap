import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../customer/confirm/client_price_approval_screen.dart';
import '../tracking/customer_tracking_screen.dart';

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});
  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  final List<Map<String, dynamic>> _bids = [];
  StreamSubscription? _jobsSub;
  final Map<String, StreamSubscription> _bidsSubs = {};
  List<DocumentSnapshot> _activeJobs = [];
  StreamSubscription? _activeSub;

  @override
  void initState() {
    super.initState();
    var uid = FirebaseAuth.instance.currentUser!.uid;

    _jobsSub = FirebaseFirestore.instance
        .collection('jobs')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['open', 'bidding'])
        .snapshots()
        .listen((jobsSnap) {
          for (var jobDoc in jobsSnap.docs) {
            var jobId = jobDoc.id;
            if (_bidsSubs.containsKey(jobId)) continue;
            _bidsSubs[jobId] = FirebaseFirestore.instance
                .collection('jobs')
                .doc(jobId)
                .collection('bids')
                .snapshots()
                .listen((bidsSnap) {
                  _bids.removeWhere((b) => b['jobId'] == jobId);
                  for (var b in bidsSnap.docs) {
                    var bid = b.data();
                    if (bid['status'] == 'rejected' ||
                        bid['status'] == 'accepted' ||
                        bid['deletedForFundi'] == true)
                      continue;
                    _bids.add({
                      'jobId': jobId,
                      'jobTitle': jobDoc.data()['title'] ?? '',
                      'bid': bid,
                      'fundiName': bid['fundiName'] ?? 'Fundi',
                      'price': bid['price'] ?? 0,
                    });
                  }
                  if (mounted) setState(() {});
                });
          }
        });

    _activeSub = FirebaseFirestore.instance
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
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _activeJobs = snap.docs);
        });
  }

  Future<void> _payEscrow(
    BuildContext context,
    String jobId,
    double amount,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'escrowStatus': 'held', // <-- was 'paid', now 'held' to match fundi tab
        'escrowAmount': amount,
        'escrowPaidAt': FieldValue.serverTimestamp(),
        'escrowHeld': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Escrow locked KES ${amount.toInt()} - Fundi can now start travelling',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _confirmCompletion(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
    });
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    _activeSub?.cancel();
    for (var s in _bidsSubs.values) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bids.isEmpty && _activeJobs.isEmpty) {
      return Center(
        child: Text('No notifications', style: GoogleFonts.inter()),
      );
    }

    List<Widget> cards = [];

    // 1. ESCROW PENDING
    for (var doc in _activeJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var jobId = doc.id;
      var escrow = (job['escrowStatus'] ?? 'pending').toString();
      var status = (job['status'] ?? '').toString();
      if ((status == 'assigned' || status == 'confirmed') &&
          escrow == 'pending') {
        double agreed = (job['agreedPrice'] ?? job['budget'] ?? 0).toDouble();
        cards.add(
          Card(
            color: Colors.yellow.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Fundi confirmed - Lock payment to escrow',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Agreed: KES ${agreed.toInt()} • Escrow: $escrow',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: FundipapColors.primaryYellow),
                    ),
                    child: Text(
                      'Pay KES ${agreed.toInt()} to escrow before fundi starts travelling. Money stays locked until you confirm completion.',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.primaryYellow,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _payEscrow(context, jobId, agreed),
                      child: Text(
                        'Pay KES ${agreed.toInt()} to Escrow (Mpesa Simulated)',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // 2. BIDS
    for (var b in _bids) {
      cards.add(
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: FundipapColors.blackGray,
              child: Text(
                b['fundiName'].toString().isNotEmpty
                    ? b['fundiName'][0].toUpperCase()
                    : 'F',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              '${b['fundiName']} sent a bid',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            subtitle: Text(
              '${b['jobTitle']} • KES ${b['price']}',
              style: GoogleFonts.inter(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );
    }

    // 3. OTHER ACTIVE
    for (var doc in _activeJobs) {
      var job = doc.data() as Map<String, dynamic>;
      var jobId = doc.id;
      var escrow = (job['escrowStatus'] ?? 'pending').toString();
      var status = (job['status'] ?? '').toString();
      if ((status == 'assigned' || status == 'confirmed') &&
          escrow == 'pending')
        continue;

      if ((status == 'assigned' || status == 'confirmed') &&
          (escrow == 'held' || escrow == 'paid')) {
        cards.add(
          _simpleCard(
            'Escrow locked - Waiting for fundi to start',
            job['title'] ?? '',
            Icons.lock_open,
            Colors.green.shade50,
          ),
        );
        continue;
      }

      var reneg = job['renegotiation'] as Map<String, dynamic>?;
      bool travelling =
          (job['travelling'] == true) ||
          (job['siteVisitStarted'] == true) ||
          status == 'travelling';
      bool isArrived =
          job['siteVisitDone'] == true &&
          status == 'site_visit' &&
          (reneg == null || reneg['requested'] != true);
      bool showReneg =
          reneg != null &&
          reneg['requested'] == true &&
          reneg['status'] != 'accepted';
      bool isCompleted =
          (reneg != null &&
          (reneg['currentPhase'] == 'completed_by_fundi' ||
              status == 'job_completed' ||
              status == 'pending_completion'));
      bool isWorking =
          (reneg != null &&
          (reneg['currentPhase'] == 'fundi_working' ||
              reneg['currentPhase'] == 'parts_confirmed_by_fundi'));

      if (travelling && job['siteVisitDone'] != true) {
        cards.add(
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerTrackingScreen(jobId: jobId, job: job),
              ),
            ),
            child: _simpleCard(
              'Fundi is travelling - TAP TO TRACK LIVE',
              '${job['title'] ?? ''} • ${(job['fundiLiveDistance'] ?? 0).toStringAsFixed(0)}m away • Live',
              Icons.location_on,
              Colors.blue.shade50,
            ),
          ),
        );
      } else if (isArrived) {
        // NEW: Fundi arrived notification
        cards.add(
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fundi has arrived at your location!',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${job['title'] ?? ''} • He marked arrived with GPS • Inspecting site now',
                          style: GoogleFonts.inter(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (showReneg) {
        // your existing reneg card...
        cards.add(
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                          builder: (_) =>
                              ClientPriceApprovalScreen(jobId: jobId, job: job),
                        ),
                      ),
                      child: Text(
                        'REVIEW BREAKDOWN & PHOTOS',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (isWorking) {
        String title = reneg['currentPhase'] == 'fundi_working'
            ? 'Fundi is working...'
            : 'Fundi confirmed parts';
        cards.add(
          _simpleCard(
            title,
            job['title'] ?? '',
            Icons.construction,
            Colors.green.shade50,
          ),
        );
      } else if (isCompleted) {
        cards.add(
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Job Completed - Review & Release Payment',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FundipapColors.greenSuccess,
                      ),
                      onPressed: () => _confirmCompletion(jobId),
                      child: const Text(
                        'Confirm Completion & Release Payment',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return ListView(padding: const EdgeInsets.all(12), children: cards);
  }

  Widget _simpleCard(String title, String body, IconData icon, Color bg) {
    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                      fontSize: 12,
                    ),
                  ),
                  Text(body, style: GoogleFonts.inter(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
