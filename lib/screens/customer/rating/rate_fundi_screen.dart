import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class RateFundiScreen extends StatefulWidget {
  final String jobId;
  final String fundiId;
  final String fundiName;
  final String trade;
  const RateFundiScreen({
    super.key,
    required this.jobId,
    required this.fundiId,
    required this.fundiName,
    required this.trade,
  });
  @override
  State<RateFundiScreen> createState() => _RateFundiScreenState();
}

class _RateFundiScreenState extends State<RateFundiScreen> {
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
      if (mounted) {
        setState(() {
          _job = doc.data();
          _loadingJob = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingJob = false);
    }
  }

  void _onStarTap(int index) {
    double halfRating = index + 0.5;
    double fullRating = index + 1.0;

    if (_rating == halfRating) {
      setState(() => _rating = fullRating); // 2nd tap = full
    } else if (_rating == fullRating) {
      setState(() => _rating = halfRating); // 3rd tap = half again
    } else {
      setState(() => _rating = halfRating); // 1st tap = half (odd = half)
    }
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

      String clientId =
          (jobData['clientId'] ?? jobData['customerId'] ?? 'unknown')
              .toString();
      String clientName =
          (jobData['clientName'] ?? jobData['customerName'] ?? 'Client')
              .toString();

      // GET FUNDI ID SAFELY - check every possible key
      String effectiveFundiId = widget.fundiId.trim();
      if (effectiveFundiId.isEmpty) {
        effectiveFundiId =
            (jobData['fundiId'] ??
                    jobData['assignedFundiId'] ??
                    jobData['acceptedFundiId'] ??
                    jobData['selectedFundiId'] ??
                    jobData['fundiUid'] ??
                    '')
                .toString();
      }

      if (effectiveFundiId.isEmpty) {
        // If still empty, at least mark job as rated so user is not locked forever
        await jobRef.update({
          'clientRated': true,
          'clientRating': _rating,
          'clientReview': _reviewCtrl.text.trim(),
          'ratedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      await FirebaseFirestore.instance
          .collection('fundis')
          .doc(effectiveFundiId)
          .collection('reviews')
          .add({
            'jobId': widget.jobId,
            'clientId': clientId,
            'clientName': clientName,
            'fundiId': effectiveFundiId,
            'rating': _rating,
            'comment': _reviewCtrl.text.trim(),
            'trade': widget.trade,
            'createdAt': FieldValue.serverTimestamp(),
          });

      var fundiRef = FirebaseFirestore.instance
          .collection('fundis')
          .doc(effectiveFundiId);
      var fundiSnap = await fundiRef.get();
      var fundiData = fundiSnap.data() ?? {};
      double currentAvg = (fundiData['averageRating'] ?? 0).toDouble();
      int currentCount = (fundiData['reviewsCount'] ?? 0).toInt();
      double newAvg =
          ((currentAvg * currentCount) + _rating) / (currentCount + 1);

      await fundiRef.update({
        'averageRating': newAvg,
        'reviewsCount': currentCount + 1,
        'lastRatedAt': FieldValue.serverTimestamp(),
      });

      await jobRef.update({
        'clientRated': true,
        'clientRating': _rating,
        'clientReview': _reviewCtrl.text.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'clientTimelineCleared': true,
        'fundiHasUnread': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildStar(int index) {
    IconData icon;
    if (_rating >= index + 1) {
      icon = Icons.star;
    } else if (_rating >= index + 0.5) {
      icon = Icons.star_half;
    } else {
      icon = Icons.star_border;
    }

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
    String title = (_job?['title'] ?? _job?['description'] ?? 'Job').toString();
    String location = (_job?['location'] ?? _job?['address'] ?? 'Your location')
        .toString();
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
              'You MUST rate ${widget.fundiName} before going back',
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
            'Rate Fundi - Mandatory',
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Why your rating matters',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your honest rating helps FundiApp verify legitimate, skilled and trustworthy fundis. Highly rated fundis earn more jobs and visibility, while consistently low-rated fundis are reviewed and removed. By rating ${widget.fundiName}, you protect the next client and keep our community safe and reliable.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: FundipapColors.blackGray,
                            child: Text(
                              widget.fundiName.isNotEmpty
                                  ? widget.fundiName[0].toUpperCase()
                                  : 'F',
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Job completed by ${widget.fundiName}',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.trade} • $location • KES $paid released',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What ${widget.fundiName} did:',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap left side of star for 0.5, right side for full. Tap same star twice to toggle 5 → 4.5',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Your rating',
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
                        hintText:
                            'How was ${widget.fundiName}\'s work? Be honest - your review builds trust.',
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
                                'SUBMIT ${_rating > 0 ? '${_rating.toStringAsFixed(_rating.truncateToDouble() == _rating ? 0 : 1)}★' : ''} & UNLOCK APP',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Locked until rated - reappears on relaunch',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.black45,
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
