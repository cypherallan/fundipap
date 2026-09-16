import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import 'fundi_add_part_receipt.dart';
import 'fundi_request_new_price.dart'; // <-- ADD

class FundiConfirmedTab extends StatelessWidget {
  final Stream<QuerySnapshot> jobsStream;
  final Future<void> Function(String jobId) onRequestNewPrice;
  final Future<void> Function(String jobId) onStartJob;
  final Future<void> Function(String jobId) onAddParts;
  final Future<void> Function(String jobId) onMarkCompleted;

  const FundiConfirmedTab({
    super.key,
    required this.jobsStream,
    required this.onRequestNewPrice,
    required this.onStartJob,
    required this.onAddParts,
    required this.onMarkCompleted,
  });

  Future<void> _startSiteVisit(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisitCustomerScreen(jobId: jobId, job: job),
      ),
    );
  }

  void _openNewPrice(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FundiRequestNewPriceScreen(jobId: jobId, job: job),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: jobsStream,
      builder: (_, snap) {
        if (snap.hasError)
          return Center(child: SelectableText('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snap.data!.docs
            .where(
              (d) => [
                'assigned',
                'site_visit',
                'in_progress',
                'pending_completion',
              ].contains((d.data() as Map)['status']),
            )
            .toList();
        if (docs.isEmpty)
          return Center(
            child: Text(
              'No confirmed jobs',
              style: GoogleFonts.inter(color: Colors.black45),
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            var job = docs[i].data() as Map<String, dynamic>;
            var jobId = docs[i].id;
            String escrow = job['escrowStatus'] ?? 'pending';
            bool siteDone = job['siteVisitDone'] ?? false;
            var reneg = job['renegotiation'] as Map<String, dynamic>?;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FundipapColors.greenSuccess),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${job['status'].toString().toUpperCase()} • KES ${job['agreedPrice'] ?? job['budget']}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Client: ${job['customerName'] ?? job['clientName'] ?? 'Client'} • Escrow: $escrow',
                    style: GoogleFonts.inter(fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  if (escrow != 'held')
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Waiting for client to pay to escrow. You cannot start until held.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  if (escrow == 'held') ...[
                    if (!siteDone) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.blackGray,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                          ),
                          onPressed: () => _startSiteVisit(context, jobId, job),
                          icon: const Icon(Icons.navigation, size: 20),
                          label: Text(
                            'Start Site Visit - Must Visit First',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Visit site & mark arrived to unlock price request & start job',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.grey.shade600,
                              ),
                              onPressed: null, // LOCKED
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock, size: 12),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Request New Price',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade300,
                                foregroundColor: Colors.grey.shade600,
                              ),
                              onPressed: null, // LOCKED
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock, size: 12),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Start Job',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (siteDone) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✓ Site visited. Client notified. Status: ${job['status']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (reneg != null &&
                          reneg['requested'] == true &&
                          reneg['status'] != 'accepted') ...[
                        if (reneg['status'] == 'countered_by_client')
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Client countered: KES ${reneg['counterPrice'] ?? reneg['newLaborTotal'] ?? reneg['newPrice']}',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'Reason: ${reneg['reason'] ?? ''}',
                                  style: GoogleFonts.inter(fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await FirebaseFirestore.instance
                                              .collection('jobs')
                                              .doc(jobId)
                                              .update({
                                               'agreedPrice': reneg['counterPrice'] ?? reneg['newLaborTotal'] ?? reneg['newPrice'],
'laborPrice': reneg['counterPrice'] ?? reneg['newLaborTotal'] ?? reneg['newPrice'],
                                                'renegotiation': {
                                                  'requested': false,
                                                  'status': 'accepted',
                                                },
                                                'status': 'site_visit',
                                              });
                                        },
                                        child: const Text(
                                          'Accept Client Price',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _openNewPrice(context, jobId, job),
                                        child: const Text('Counter'),
                                      ),
                                    ), // <-- FIXED
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Builder(
                            builder: (_) {
                              int extra =
                                  (reneg['extraLabor'] ??
                                          reneg['pendingLabor'] ??
                                          0)
                                      as int;
                              int newLab =
                                  (reneg['newLaborTotal'] ??
                                          reneg['newPrice'] ??
                                          0)
                                      as int;
                              int parts =
                                  (reneg['partsEstimateTotal'] ??
                                          reneg['partsTotal'] ??
                                          0)
                                      as int;
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'You asked extra KES $extra. Total labor KES $newLab',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Parts est KES $parts (paid direct to shop) - Waiting client...',
                                      style: GoogleFonts.inter(fontSize: 10),
                                    ),
                                    const SizedBox(height: 4),
                                    const LinearProgressIndicator(),
                                  ],
                                ),
                              );
                            },
                          ),
                      ] else if (job['status'] == 'assigned' ||
                          job['status'] == 'site_visit')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => onStartJob(jobId),
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
                                onPressed: () =>
                                    _openNewPrice(context, jobId, job),
                                child: const Text('Request New Price'),
                              ),
                            ), // <-- FIXED
                          ],
                        ),
                      if (job['status'] == 'in_progress')
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FundiAddPartReceiptScreen(
                                      jobId: jobId,
                                      job: job,
                                    ),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black),
                                ),
                                child: Text(
                                  'Add Part Receipt',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => onMarkCompleted(jobId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: FundipapColors.primaryYellow,
                                  foregroundColor: Colors.black,
                                ),
                                child: Text(
                                  'Mark Completed',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (job['status'] == 'pending_completion')
                        Text(
                          'Waiting for client to confirm completion to release KES ${job['agreedPrice']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// _VisitCustomerScreen stays same as you have...
class _VisitCustomerScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const _VisitCustomerScreen({required this.jobId, required this.job});
  @override
  State<_VisitCustomerScreen> createState() => _VisitCustomerScreenState();
}

class _VisitCustomerScreenState extends State<_VisitCustomerScreen> {
  Position? currentPos;
  double distance = 999999;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _track();
  }

  Future<void> _track() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((p) {
      double lat = (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
          .toDouble();
      double lng = (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
          .toDouble();
      double d = Geolocator.distanceBetween(p.latitude, p.longitude, lat, lng);
      if (mounted) {
        setState(() {
          currentPos = p;
          distance = d;
          loading = false;
        });
      }
    });
  }

  Future<void> _openMaps() async {
    double lat = (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
        .toDouble();
    double lng = (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
        .toDouble();
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmVisited() async {
    if (distance > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are ${distance.toStringAsFixed(0)}m away. Get within 100m',
          ),
        ),
      );
      return;
    }
    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update({
          'siteVisitDone': true,
          'siteVisited': true,
          'siteVisitedAt': FieldValue.serverTimestamp(),
          'fundiLatAtVisit': currentPos?.latitude,
          'fundiLngAtVisit': currentPos?.longitude,
          'status': 'site_visit',
        });
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Site visit confirmed with GPS')),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool canMark = distance <= 100;
    return Scaffold(
      appBar: AppBar(
        title: Text('Visit ${widget.job['customerName'] ?? 'Customer'}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  Text(
                    widget.job['title'] ?? '',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.job['location'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (loading)
                    const CircularProgressIndicator()
                  else
                    Text(
                      '${distance.toStringAsFixed(0)}m away',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: canMark ? Colors.green : Colors.red,
                        fontSize: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _openMaps,
                icon: const Icon(Icons.directions),
                label: const Text('Open Directions in Maps'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canMark
                      ? FundipapColors.primaryYellow
                      : Colors.grey.shade300,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: canMark ? _confirmVisited : null,
                icon: Icon(canMark ? Icons.check_circle : Icons.location_off),
                label: Text(
                  canMark
                      ? 'I have arrived - Mark Site Visited'
                      : 'Move within 100m to mark',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
