import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import 'fundi_add_part_receipt.dart';
import 'fundi_request_new_price_screen.dart';
import '../../../services/job_cancel_service.dart'; // <-- NEW

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

  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return true; // if Timestamp / exists, treat as true
  }

  Future<void> _startSiteVisit(
    BuildContext context,
    String jobId,
    Map<String, dynamic> job,
  ) async {
    // 1. get fundi current pos FIRST
    Position? pos;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {}

    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'travelling': true,
      'siteVisitStarted': true,
      'travellingAt': FieldValue.serverTimestamp(),
      'siteVisitStartedAt': FieldValue.serverTimestamp(),
      'status': 'travelling',
      'siteVisitDone': false,
      'siteVisited': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (pos != null) 'fundiLiveLat': pos.latitude,
      if (pos != null) 'fundiLiveLng': pos.longitude,
    });

    if (!context.mounted) return;

    // 2. Prompt to open Maps immediately with both points
    double cLat = (job['customerLat'] ?? job['lat'] ?? -0.0917).toDouble();
    double cLng = (job['customerLng'] ?? job['lng'] ?? 34.7680).toDouble();
    // handle GeoPoint too
    if (job['clientLocation'] is GeoPoint) {
      cLat = (job['clientLocation'] as GeoPoint).latitude;
      cLng = (job['clientLocation'] as GeoPoint).longitude;
    }

    bool openMaps =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Start Navigation?'),
            content: Text('Open Google Maps with route to client?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Open Maps'),
              ),
            ],
          ),
        ) ??
        false;

    if (openMaps) {
      String url = pos != null
          ? 'https://www.google.com/maps/dir/?api=1&origin=${pos.latitude},${pos.longitude}&destination=$cLat,$cLng&travelmode=driving'
          : 'https://www.google.com/maps/dir/?api=1&destination=$cLat,$cLng';
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    // 3. Still open your tracking screen so fundiLive continues updating
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

        final allDocs = snap.data!.docs;
        var docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final s = data['status']?.toString().toLowerCase() ?? '';
          return [
            'confirmed',
            'assigned',
            'travelling',
            'site_visit',
            'in_progress',
            'pending_completion',
            'job_completed',
          ].contains(s);
        }).toList();

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
            String escrow = (job['escrowStatus'] ?? 'pending')
                .toString()
                .toLowerCase();
            bool escrowDone =
                escrow == 'held' || escrow == 'paid' || escrow == 'released';
            bool siteDone =
                _toBool(job['siteVisitDone']) ||
                _toBool(job['siteVisited']) ||
                job['siteVisitedAt'] != null;
            bool isTravelling =
                !siteDone &&
                (job['travelling'] == true ||
                    (job['status'] ?? '').toString() == 'travelling');
            bool isStarted = [
              'in_progress',
              'pending_completion',
              'job_completed',
            ].contains((job['status'] ?? '').toString());
            int agreedPrice =
                (job['agreedPrice'] ??
                        job['acceptedBidAmount'] ??
                        job['fundiBidAmount'] ??
                        job['budget'] ??
                        0)
                    .toInt();

            var reneg = job['renegotiation'] as Map<String, dynamic>?;
            bool renegPending =
                reneg != null &&
                reneg['requested'] == true &&
                (reneg['status'] ?? 'pending') == 'pending';
            bool canFundiCancel =
                (job['status'] == 'assigned' || job['status'] == 'confirmed') &&
                !isTravelling &&
                !siteDone &&
                !isStarted;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: job['status'] == 'in_progress'
                    ? Colors.orange.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: job['status'] == 'in_progress'
                      ? Colors.orange.shade400
                      : FundipapColors.greenSuccess,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${job['status'].toString().toUpperCase()} • KES $agreedPrice',
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

                  if (!escrowDone)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.hourglass_top,
                                size: 16,
                                color: Colors.orange.shade800,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Waiting for client to pay KES $agreedPrice to escrow',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You will be notified once escrow is locked. Then you can start site visit.',
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                  // 2. ESCROW DONE
                  if (escrowDone) ...[
                    if (renegPending) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          'Waiting for client to approve extra KES ${reneg['extraToLock'] ?? reneg['extraLabor'] ?? ''}',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.purple.shade800,
                          ),
                        ),
                      ),
                    ] else if (!siteDone && !isTravelling) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.blackGray,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _startSiteVisit(context, jobId, job),
                          icon: const Icon(Icons.navigation, size: 20),
                          label: Text(
                            'START SITE VISIT - I AM ON THE WAY',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ] else if (!siteDone && isTravelling) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.blue.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'You are on the way - client sees you travelling',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FundipapColors.primaryYellow,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _VisitCustomerScreen(jobId: jobId, job: job),
                            ),
                          ),
                          icon: const Icon(Icons.map),
                          label: const Text('OPEN TRACKING / CONFIRM ARRIVAL'),
                        ),
                      ),
                    ] else if (siteDone) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '✓ Site visited - GPS verified. Status: ${job['status']}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!isStarted)
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
                            ),
                          ],
                        ),
                      if (isStarted && job['status'] == 'in_progress')
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
                                child: Text(
                                  'Add Part Receipt',
                                  style: GoogleFonts.montserrat(fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('jobs')
                                      .doc(jobId)
                                      .update({'status': 'job_completed'});
                                  onMarkCompleted(jobId);
                                },
                                child: const Text('Mark Completed'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],

                  if (canFundiCancel) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300),
                          foregroundColor: Colors.red.shade700,
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: Text(
                          'Cancel Job - Client gets full refund',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => JobCancelService.showCancelDialog(
                          context: context,
                          jobId: jobId,
                          job: job,
                          isClient: false,
                        ),
                      ),
                    ),
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
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) async {
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
      try {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'fundiLiveLat': p.latitude,
              'fundiLiveLng': p.longitude,
              'fundiLiveAt': FieldValue.serverTimestamp(),
              'fundiLiveDistance': d,
            });
      } catch (_) {}
    });
  }

  Future<void> _openMaps() async {
    double cLat = (widget.job['customerLat'] ?? widget.job['lat'] ?? -0.0917)
        .toDouble();
    double cLng = (widget.job['customerLng'] ?? widget.job['lng'] ?? 34.7680)
        .toDouble();
    if (widget.job['clientLocation'] is GeoPoint) {
      cLat = (widget.job['clientLocation'] as GeoPoint).latitude;
      cLng = (widget.job['clientLocation'] as GeoPoint).longitude;
    }
    String url;
    if (currentPos != null) {
      url =
          'https://www.google.com/maps/dir/?api=1&origin=${currentPos!.latitude},${currentPos!.longitude}&destination=$cLat,$cLng&travelmode=driving';
    } else {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$cLat,$cLng';
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
          'travelling': false, // FIX: force false
          'travellingAt': FieldValue.delete(), // clear travelling
          'status': 'site_visit',
          'fundiHasUnread': false,
          'customerHasUnread': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    if (!mounted) return;
    Navigator.pop(context); // back to list
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '✓ Site visit confirmed - Now START JOB or Request New Price',
        ),
      ),
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
