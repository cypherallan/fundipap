import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../app.dart'; // HomeNavigator = bottom tabs host

class RateClientScreen extends StatefulWidget {
  final String jobId;
  final String clientId;
  final String clientName;
  final String trade;
  const RateClientScreen({
    super.key,
    required this.jobId,
    required this.clientId,
    required this.clientName,
    required this.trade,
  });
  @override
  State<RateClientScreen> createState() => _RateClientScreenState();
}

class _RateClientScreenState extends State<RateClientScreen> {
  double _rating = 0;
  final TextEditingController _reviewCtrl = TextEditingController();
  bool _submitting = false;
  Map<String, dynamic>? _job;
  bool _loadingJob = true;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .get();
      if (!mounted) return;
      setState(() {
        _job = doc.data();
        _loadingJob = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingJob = false);
    }
  }

  void _onStarTap(int index) {
    double halfRating = index + 0.5;
    double fullRating = index + 1.0;
    if (_rating == halfRating) {
      setState(() => _rating = fullRating);
    } else if (_rating == fullRating) {
      setState(() => _rating = halfRating);
    } else {
      setState(() => _rating = halfRating);
    }
  }

  Future<void> _goHomeWithTabs() async {
    if (!mounted) return;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeNavigator(role: 'fundi', email: email),
      ),
      (route) => false,
    );
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select stars')));
      return;
    }
    if (_reviewCtrl.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write at least 5 characters')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      var jobRef = FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId);
      var jobSnap = await jobRef.get();
      var jobData = jobSnap.data() ?? {};

      String effectiveClientId = widget.clientId.trim();
      if (effectiveClientId.isEmpty) {
        effectiveClientId =
            (jobData['clientId'] ??
                    jobData['customerId'] ??
                    jobData['userId'] ??
                    '')
                .toString();
      }

      if (effectiveClientId.isEmpty) {
        await jobRef.update({
          'fundiRated': true,
          'fundiRating': _rating,
          'fundiReview': _reviewCtrl.text.trim(),
          'fundiRatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _goHomeWithTabs();
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(effectiveClientId)
          .collection('clientReviews')
          .add({
            'jobId': widget.jobId,
            'clientId': effectiveClientId,
            'clientName': widget.clientName,
            'fundiId': jobData['fundiId'] ?? jobData['assignedFundiId'] ?? '',
            'rating': _rating,
            'comment': _reviewCtrl.text.trim(),
            'trade': widget.trade,
            'createdAt': FieldValue.serverTimestamp(),
          });

      var clientRef = FirebaseFirestore.instance
          .collection('users')
          .doc(effectiveClientId);
      var clientSnap = await clientRef.get();
      var clientData = clientSnap.data() ?? {};
      double currentAvg =
          (clientData['averageClientRating'] ?? clientData['clientRating'] ?? 0)
              .toDouble();
      int currentCount = (clientData['clientReviewsCount'] ?? 0).toInt();
      double newAvg =
          ((currentAvg * currentCount) + _rating) / (currentCount + 1);

      await clientRef.set({
        'averageClientRating': newAvg,
        'clientReviewsCount': currentCount + 1,
        'lastRatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await jobRef.update({
        'fundiRated': true,
        'fundiRating': _rating,
        'fundiReview': _reviewCtrl.text.trim(),
        'fundiRatedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'fundiTimelineCleared': true,
        'customerHasUnread': true,
        'fundiHasUnread': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _goHomeWithTabs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildStar(int index) {
    IconData icon;
    if (_rating >= index + 1)
      icon = Icons.star;
    else if (_rating >= index + 0.5)
      icon = Icons.star_half;
    else
      icon = Icons.star_border;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onStarTap(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          icon,
          size: 42,
          color: _rating > index ? Colors.amber : Colors.grey.shade300,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // title removed - was unused, caused lint
    String location =
        (_job?['location'] ?? _job?['address'] ?? 'Client location').toString();
    int paid =
        (_job?['totalReleasedAmount'] ??
                _job?['fundiPayoutAmount'] ??
                _job?['agreedPrice'] ??
                0)
            is int
        ? (_job?['totalReleasedAmount'] ??
                  _job?['fundiPayoutAmount'] ??
                  _job?['agreedPrice'] ??
                  0)
              as int
        : int.tryParse(
                (_job?['totalReleasedAmount'] ??
                        _job?['fundiPayoutAmount'] ??
                        _job?['agreedPrice'] ??
                        0)
                    .toString(),
              ) ??
              0;

    final ratingLabels = [
      '0.0 Tap to rate',
      '0.5 Poor',
      '1.0 Poor',
      '1.5 Poor+',
      '2.0 Fair',
      '2.5 Fair+',
      '3.0 Good',
      '3.5 Good+',
      '4.0 Very Good',
      '4.5 Excellent-',
      '5.0 Excellent',
    ];
    int idx = (_rating * 2).toInt().clamp(0, 10);
    String ratingLabel = _rating == 0
        ? 'Tap to rate'
        : '${_rating.toStringAsFixed(_rating.truncateToDouble() == _rating ? 0 : 1)} / 5 - ${ratingLabels[idx]}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You MUST rate ${widget.clientName} before going back',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Rate Client - Mandatory',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
          ),
          backgroundColor: Colors.orange.shade50,
        ),
        body: _loadingJob
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: FundipapColors.blackGray,
                            child: Text(
                              widget.clientName.isNotEmpty
                                  ? widget.clientName[0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Job done for ${widget.clientName}',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.trade} • $location • KES $paid received',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Your rating for client',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => _buildStar(i)),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        ratingLabel,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reviewCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'How was ${widget.clientName} as a client?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FundipapColors.primaryYellow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting ? null : _submitRating,
                        child: _submitting
                            ? const CircularProgressIndicator()
                            : Text(
                                'SUBMIT & UNLOCK APP',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
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
