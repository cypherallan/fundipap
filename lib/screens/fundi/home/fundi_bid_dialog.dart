import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';
import '../../../services/dynamic_pricing_service.dart';

/// FUNDI BID DIALOG - NEW MARKET-DRIVEN PRICING
/// Fundi dictates first price, sees average guidance, system learns

class FundiBidDialog extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;
  const FundiBidDialog({super.key, required this.jobId, required this.jobData});

  @override
  State<FundiBidDialog> createState() => _FundiBidDialogState();
}

class _FundiBidDialogState extends State<FundiBidDialog> {
  final _priceCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _stats;

  String get categoryId =>
      widget.jobData['categoryId'] ??
      widget.jobData['category'] ??
      'electrical';
  String get subcategoryId => widget.jobData['subcategoryId'] ?? '';
  String? get faultId => widget.jobData['faultId'];

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Pre-fill with average if exists
    _priceCtrl.text = '';
  }

  Future<void> _loadStats() async {
    var stats = await DynamicPricingService.getStats(
      categoryId,
      subcategoryId,
      faultId: faultId,
    );
    if (!mounted) return;
    setState(() => _stats = stats);
    // use local copy for promotion
    final s = stats;
    if (s != null && s['avg'] != null && _priceCtrl.text.isEmpty) {
      _priceCtrl.text = s['avg'].toString();
    }
  }

  Future<void> _submitBid() async {
    int amount = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (amount < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid price min KES 200')),
      );
      return;
    }
    if (amount > 80000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price too high max KES 80,000')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      var fundiDoc = await FirebaseFirestore.instance
          .collection('fundis')
          .doc(uid)
          .get();
      var u = userDoc.data() ?? {};
      var f = fundiDoc.data() ?? {};

      // 1. Create bid
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .collection('bids')
          .doc(uid)
          .set({
            'fundiId': uid,
            'jobId': widget.jobId,
            'amount': amount,
            'bidAmount': amount,
            'note': _noteCtrl.text.trim(),
            'fundiName': u['name'] ?? f['name'] ?? 'Fundi',
            'fundiRating': f['averageRating'] ?? f['rating'] ?? 4.5,
            'fundiJobsCompleted': f['jobsCompleted'] ?? 0,
            'fraudCount': f['fraudCount'] ?? 0,
            'fundiPhoto': u['photoUrl'] ?? f['photoUrl'],
            'categoryId': categoryId,
            'subcategoryId': subcategoryId,
            'faultId': faultId,
            'status': 'pending',
            'isReadByCustomer': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // 2. Record for dynamic average (market learning)
      await DynamicPricingService.recordBid(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        faultId: faultId,
        bidAmount: amount,
        fundiId: uid,
        jobId: widget.jobId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bid KES $amount sent • Avg now learning'),
            backgroundColor: FundipapColors.greenSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var jobTitle = widget.jobData['title'] ?? 'Job';
    var catName = widget.jobData['categoryName'] ?? categoryId;
    var subName = widget.jobData['subcategoryName'] ?? subcategoryId;
    final stats = _stats; // LOCAL COPY - fixes non-final promotion

    return AlertDialog(
      title: Text(
        'Bid for Job',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              jobTitle,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$catName > $subName ${faultId != null ? '> $faultId' : ''}',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insights,
                        size: 16,
                        color: Colors.blue.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Market Average',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (stats == null)
                    Text(
                      'No history yet for this service. You set the first price! Your bid will become the average.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    )
                  else ...[
                    Text(
                      DynamicPricingService.formatRange(stats),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${stats['count']} bids • Min ${stats['min']} • Max ${stats['max']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your Price KES *',
                hintText: stats != null ? 'Avg ${stats['avg']}' : 'e.g. 1000',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: 'You dictate price. Client can negotiate.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Note to client (optional)',
                hintText:
                    'e.g. Includes transport, 1hr labour, 2 weeks warranty',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: Bids close to average win 3x more. Too low = client doubts quality, too high = ignored.',
              style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submitBid,
          style: ElevatedButton.styleFrom(
            backgroundColor: FundipapColors.blackGray,
            foregroundColor: Colors.white,
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'SEND BID KES ${_priceCtrl.text.isEmpty ? '' : _priceCtrl.text}',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
