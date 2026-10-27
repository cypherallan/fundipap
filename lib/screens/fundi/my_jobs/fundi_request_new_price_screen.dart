/*import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/fundi_badge_service.dart';

class FundiRequestNewPriceScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const FundiRequestNewPriceScreen({
    super.key,
    required this.jobId,
    required this.job,
  });
  @override
  State<FundiRequestNewPriceScreen> createState() =>
      _FundiRequestNewPriceScreenState();
}

class _FundiRequestNewPriceScreenState
    extends State<FundiRequestNewPriceScreen> {
  final List<String> allReasons = [
    'New parts / materials needed',
    'Replacement needed (old part damaged)',
    'Job bigger / more work than expected',
    'Extra labor required',
    'Transport / distance extra',
    'Other',
  ];

  Set<String> selectedReasons = {};
  final detailsCtrl = TextEditingController();
  final extraLaborCtrl = TextEditingController(text: '0');
  final tillCtrl = TextEditingController();
  List<Map<String, TextEditingController>> partsNeeded = [];
  List<XFile> evidencePhotos = [];
  List<XFile> verificationPhotos = [];
  List<XFile> oldPartPhotos = [];
  final picker = ImagePicker();
  bool uploading = false;
  BadgeResult? badge;
  int fundiFeePct = 10;
  int clientFeePct = 5;

  String? _selectedAnchorPhoto;
  Rect _blurRect = const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4);
  bool _anchorVerified = false;

  @override
  void initState() {
    super.initState();
    _addPartNeeded();
    _loadBadge();
    _pickRandomAnchor();
  }

  void _pickRandomAnchor() {
    var photos =
        widget.job['photos'] as List? ?? widget.job['images'] as List? ?? [];
    if (photos.isNotEmpty) {
      photos.shuffle();
      _selectedAnchorPhoto = photos.first.toString();
      // random blur rect for non-movable part
      _blurRect = Rect.fromLTWH(
        0.25 + (DateTime.now().millisecond % 20) / 100,
        0.25 + (DateTime.now().millisecond % 20) / 100,
        0.4,
        0.4,
      );
    }
  }

  bool get _hasValidVerification =>
      verificationPhotos.isNotEmpty && _anchorVerified;

  Future<void> _loadBadge() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var r = await FundiBadgeService.getBadge(uid);
    setState(() {
      badge = r;
      fundiFeePct = r.fundiCommissionPct;
      clientFeePct = r.clientCommissionPct;
    });
  }

  void _addPartNeeded() {
    setState(
      () => partsNeeded.add({
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'model': TextEditingController(),
        'estPrice': TextEditingController(text: '0'),
      }),
    );
  }

  void _clearParts() {
    tillCtrl.clear();
    for (var p in partsNeeded) {
      p['name']?.clear();
      p['qty']?.text = '1';
      p['model']?.clear();
      p['estPrice']?.text = '0';
    }
    if (partsNeeded.length > 1) {
      partsNeeded = [partsNeeded.first];
    }
  }

  bool _verifying = false;
  String? _verifyReason;

  Future<void> _runAnchorCheck(String localPath) async {
    if (_selectedAnchorPhoto == null) {
      setState(() => _anchorVerified = true);
      return;
    }
    setState(() {
      _verifying = true;
      _anchorVerified = false;
      _verifyReason = null;
    });
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'jobs/${widget.jobId}/verification_temp/${DateTime.now().millisecondsSinceEpoch}_${localPath.split('/').last}',
      );
      await ref.putFile(File(localPath));
      final verifyUrl = await ref.getDownloadURL();
      final res = await FirebaseFunctions.instance
          .httpsCallable('verifyAnchorPhoto')
          .call({
            'jobId': widget.jobId,
            'clientPhotoUrl': _selectedAnchorPhoto,
            'verificationPhotoUrl': verifyUrl,
            'blurRect': {
              'left': _blurRect.left,
              'top': _blurRect.top,
              'width': _blurRect.width,
              'height': _blurRect.height,
            },
          });
      final data = Map<String, dynamic>.from(res.data);
      setState(() {
        _anchorVerified = data['verified'] == true;
        _verifyReason = data['reason'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['verified']
                  ? 'Verified ${data['score']}%: ${data['reason']}'
                  : 'FAILED: ${data['reason']}',
            ),
          ),
        );
      }
      await ref.delete().catchError((_) {});
    } catch (e) {
      setState(() {
        _verifyReason = e.toString();
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _showVerificationSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo - Camera ONLY'),
              onTap: () async {
                Navigator.pop(ctx);
                var img = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (img != null) {
                  setState(() => verificationPhotos.add(img));
                  await _runAnchorCheck(img.path);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEvidenceSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo - Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                var img = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 60,
                );
                if (img != null) setState(() => evidencePhotos.add(img));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery (multiple)'),
              onTap: () async {
                Navigator.pop(ctx);
                var imgs = await picker.pickMultiImage(imageQuality: 60);
                if (imgs.isNotEmpty)
                  setState(() => evidencePhotos.addAll(imgs));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showOldPartSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(ctx);
                var img = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 60,
                );
                if (img != null) setState(() => oldPartPhotos.add(img));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                var img = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 60,
                );
                if (img != null) setState(() => oldPartPhotos.add(img));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  bool get _needsParts =>
      selectedReasons.contains('New parts / materials needed') ||
      selectedReasons.contains('Replacement needed (old part damaged)');
  bool get _needsLabor =>
      selectedReasons.contains('Job bigger / more work than expected') ||
      selectedReasons.contains('Extra labor required') ||
      selectedReasons.contains('Transport / distance extra');

  int _toInt(dynamic v, [int fb = 0]) {
    if (v == null) return fb;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fb;
  }

  int get oldLabor => _toInt(
    widget.job['laborCost'] ??
        widget.job['agreedPrice'] ??
        widget.job['budget'] ??
        0,
  );
  int get transport =>
      _toInt(widget.job['transportFee'] ?? widget.job['escrowTransport'] ?? 0);
  int get extraLabor => _needsLabor ? _toInt(extraLaborCtrl.text) : 0;
  int get newLaborTotal => oldLabor + extraLabor;
  int get oldClientFee => (oldLabor * clientFeePct / 100).round();
  int get newClientFee => (newLaborTotal * clientFeePct / 100).round();
  int get newFundiFee => (newLaborTotal * fundiFeePct / 100).round();
  int get oldTotalClient => _toInt(
    widget.job['totalClientPays'] ??
        widget.job['totalCost'] ??
        oldLabor + transport + oldClientFee,
  );
  int get newTotalClient => newLaborTotal + transport + newClientFee;
  int get newFundiReceives => newLaborTotal - newFundiFee + transport;
  int get extraToLock => newTotalClient - oldTotalClient;

  int get partsEstimateTotal {
    if (!_needsParts) return 0;
    int total = 0;
    for (var p in partsNeeded) {
      if ((p['name']?.text.trim().isEmpty ?? true)) continue;
      int qty = int.tryParse(p['qty']?.text ?? '1') ?? 1;
      int price = int.tryParse(p['estPrice']?.text ?? '0') ?? 0;
      total += qty * price;
    }
    return total;
  }

  Future<List<String>> _uploadPhotos(List<XFile> files, String folder) async {
    List<String> urls = [];
    for (var x in files) {
      try {
        var ref = FirebaseStorage.instance.ref().child(
          'jobs/${widget.jobId}/$folder/${DateTime.now().millisecondsSinceEpoch}_${x.name}',
        );
        await ref.putFile(File(x.path));
        urls.add(await ref.getDownloadURL());
      } catch (_) {}
    }
    return urls;
  }

  Future<void> _submit() async {
    if (selectedReasons.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least 1 reason')));
      return;
    }
    // optional for testing - if provided, will be used for verification
    bool hasVerification = verificationPhotos.isNotEmpty;
    bool hasEvidence = evidencePhotos.isNotEmpty;
    if (detailsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Explain why price increased')),
      );
      return;
    }
    if (_needsLabor && extraLabor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter extra labour amount')),
      );
      return;
    }
    if (_needsParts && partsEstimateTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 1 part with price')),
      );
      return;
    }
    setState(() => uploading = true);
    try {
      bool hasParts = _needsParts;
      var evidenceUrls = await _uploadPhotos(evidencePhotos, 'evidence');
      var verificationUrls = await _uploadPhotos(
        verificationPhotos,
        'verification',
      );
      var oldPartUrls = await _uploadPhotos(oldPartPhotos, 'old_parts');

      List<Map> partsNeededData = hasParts
          ? partsNeeded
                .where((p) => (p['name']?.text.trim().isNotEmpty ?? false))
                .map(
                  (p) => {
                    'name': p['name']!.text.trim(),
                    'qty': int.tryParse(p['qty']?.text ?? '1') ?? 1,
                    'model': p['model']?.text.trim() ?? '',
                    'estPrice': int.tryParse(p['estPrice']?.text ?? '0') ?? 0,
                  },
                )
                .toList()
          : [];

      int finalPartsTotal = hasParts ? partsEstimateTotal : 0;
      String finalTill = hasParts ? tillCtrl.text.trim() : '';

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'originalLaborCost': widget.job['originalLaborCost'] ?? oldLabor,
            'laborCost': oldLabor,
            'renegotiation': {
              'requested': true,
              'status': 'pending',
              'reasons': selectedReasons.toList(),
              'reasonDetails': detailsCtrl.text.trim(),
              'oldLabor': oldLabor,
              'originalLabor': widget.job['originalLaborCost'] ?? oldLabor,
              'extraLabor': extraLabor,
              'newLaborTotal': newLaborTotal,
              'pendingLabor': extraLabor,
              'oldClientAppFee': oldClientFee,
              'newClientAppFee': newClientFee,
              'newFundiAppFee': newFundiFee,
              'transportFee': transport,
              'oldTotalClientPays': oldTotalClient,
              'newTotalClientPays': newTotalClient,
              'newFundiReceives': newFundiReceives,
              'extraToLock': extraToLock,
              'partsNeeded': partsNeededData,
              'partsEstimateTotal': finalPartsTotal,
              'partsPaymentDestination': 'shop_direct',
              'tillNumber': finalTill,
              'evidencePhotoUrls': evidenceUrls,
              'verificationPhotoUrls': verificationUrls,
              'oldPartPhotoUrls': oldPartUrls,
              'hasVerificationPhotos': hasVerification,
              'hasEvidencePhotos': hasEvidence,
              'verificationAttempted': verificationUrls.isNotEmpty,
              'counterRound': 0,
              'clientLowCounterCount': 0,
              'scopeChangeScore': 0,
              'whoBuysParts': null,
              'createdAt': FieldValue.serverTimestamp(),
              'verificationInfo': {
                'method': 'vision_api_label_match',
                'verified': _anchorVerified,
                'reason': _verifyReason,
                'anchorPhoto': _selectedAnchorPhoto,
                'timestamp': FieldValue.serverTimestamp(),
              },
            },
            'status': 'site_visit',
            'customerHasUnread': true,
            'fundiHasUnread': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'customerLastSeenAt': FieldValue.delete(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request sent to client)')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool needsParts = _needsParts;
    bool needsReplacement = selectedReasons.contains(
      'Replacement needed (old part damaged)',
    );
    bool needsLabor = _needsLabor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request Higher Price',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current: Labour KES $oldLabor + Transport KES $transport = KES ${oldLabor + transport}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Transport does not change. App Maintenance Cost = $clientFeePct% client, $fundiFeePct% you (${badge?.badgeLevel.name ?? 'bronze'}).',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select ALL reasons that apply:',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allReasons.map((r) {
                bool sel = selectedReasons.contains(r);
                return FilterChip(
                  label: Text(r, style: GoogleFonts.inter(fontSize: 11)),
                  selected: sel,
                  selectedColor: FundipapColors.primaryYellow,
                  onSelected: (v) => setState(() {
                    if (v) {
                      selectedReasons.add(r);
                    } else {
                      selectedReasons.remove(r);
                      bool stillNeedsLabor =
                          selectedReasons.contains(
                            'Job bigger / more work than expected',
                          ) ||
                          selectedReasons.contains('Extra labor required') ||
                          selectedReasons.contains(
                            'Transport / distance extra',
                          );
                      bool stillNeedsParts =
                          selectedReasons.contains(
                            'New parts / materials needed',
                          ) ||
                          selectedReasons.contains(
                            'Replacement needed (old part damaged)',
                          );
                      if (!stillNeedsLabor) extraLaborCtrl.text = '0';
                      if (!stillNeedsParts) _clearParts();
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Explain in detail',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (needsLabor) ...[
              const SizedBox(height: 16),
              Text(
                'Extra Labor',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: extraLaborCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Extra Labor KES',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            if (needsParts) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parts Needed (Client will buy)',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: _addPartNeeded,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              ...partsNeeded.asMap().entries.map((e) {
                int idx = e.key;
                var p = e.value;
                return Container(
                  key: ValueKey(p['name']),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: p['name'],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Part e.g. 1 inch pipe',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: p['qty'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: p['model'],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: p['estPrice'],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Est Price',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => partsNeeded.removeAt(idx)),
                        icon: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (needsParts) ...[
              const SizedBox(height: 12),
              TextField(
                controller: tillCtrl,
                decoration: InputDecoration(
                  labelText: 'Till Number (Optional)',
                  hintText: 'Leave blank if you dont know shops around',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FundipapColors.blackGray,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill Summary - NEW PRICE',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _billRow('Old Labour:', 'KES $oldLabor'),
                  _billRow('Extra Labour:', 'KES $extraLabor', highlight: true),
                  _billRow(
                    'New Labour Total:',
                    'KES $newLaborTotal',
                    highlight: true,
                  ),
                  _billRow('Transport (same):', 'KES $transport'),
                  const Divider(color: Colors.white24),
                  _billRow('Old Total Paid:', 'KES ${oldLabor + transport}'),
                  _billRow(
                    'Extra to Lock Now:',
                    'KES ${needsLabor ? extraLabor : 0}',
                    highlightYellow: true,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    needsParts
                        ? 'Parts: ${partsNeeded.where((p) => (p['name']?.text.trim().isNotEmpty ?? false)).length} items - KES $partsEstimateTotal separate (client buys)'
                        : 'No parts requested',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasValidVerification
                      ? Colors.green
                      : Colors.blue.shade200,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _hasValidVerification
                            ? Icons.verified
                            : Icons.verified_user,
                        size: 16,
                        color: _hasValidVerification
                            ? Colors.green
                            : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SET 1 - VERIFICATION (Optional for testing) - Prove you are on site',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: _hasValidVerification
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optional for now. When added: system picks random client photo, blurs fixed anchor (non-movable). Retake revealing it to prove on site.',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  if (_selectedAnchorPhoto != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Client anchor - blurred part must be revealed in your retake (tap to view full):',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: const EdgeInsets.all(12),
                            child: Stack(
                              children: [
                                Center(
                                  child: InteractiveViewer(
                                    child: Image.network(
                                      _selectedAnchorPhoto!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                // blur in full view too
                                Positioned.fill(
                                  child: LayoutBuilder(
                                    builder: (c, cons) {
                                      return Stack(
                                        children: [
                                          Positioned(
                                            left:
                                                cons.maxWidth * _blurRect.left,
                                            top:
                                                cons.maxHeight * 0.3 +
                                                cons.maxHeight *
                                                    _blurRect.top *
                                                    0.4,
                                            width:
                                                cons.maxWidth * _blurRect.width,
                                            height:
                                                cons.maxHeight *
                                                _blurRect.height,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: 20,
                                                  sigmaY: 20,
                                                ),
                                                child: Container(
                                                  color: Colors.black
                                                      .withOpacity(0.2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Blurred area = fixed anchor you must reveal in your retake',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
                          final w = constraints.maxWidth;
                          const h = 120.0;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _selectedAnchorPhoto!,
                                  height: h,
                                  width: w,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                left: w * _blurRect.left,
                                top: h * _blurRect.top,
                                width: w * _blurRect.width,
                                height: h * _blurRect.height,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 18,
                                      sigmaY: 18,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.25),
                                        border: Border.all(
                                          color: Colors.white70,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.zoom_in,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Tap to enlarge',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: verificationPhotos
                        .map(
                          (x) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(x.path),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (_verifying) const LinearProgressIndicator(),
                  if (_verifyReason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _verifyReason!,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: _anchorVerified ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _verifying ? null : _showVerificationSourceSheet,
                    icon: Icon(
                      _verifying ? Icons.hourglass_top : Icons.camera_alt,
                      size: 16,
                      color: _hasValidVerification ? Colors.green : Colors.blue,
                    ),
                    label: Text(
                      _verifying
                          ? 'Verifying with Vision API...'
                          : _hasValidVerification
                          ? 'Verified ✓ Retake if needed'
                          : 'Retake revealing blurred anchor (in-app camera)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _hasValidVerification
                            ? Colors.green.shade800
                            : Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_camera,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SET 2 - EVIDENCE (Optional for now)',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'New photos showing WHY extra needed (no space, no water, bigger scope, materials). Taken within 10 mins after Set 1, same GPS. Generic - not hardcoded.',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: evidencePhotos
                        .map(
                          (x) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(x.path),
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => evidencePhotos.remove(x)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showEvidenceSourceSheet,
                    icon: const Icon(Icons.photo, size: 16),
                    label: const Text(
                      'Add evidence photos - why extra needed',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            if (needsReplacement) ...[
              const SizedBox(height: 12),
              Text(
                'OLD damaged part photo',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: Colors.red,
                ),
              ),
              Wrap(
                spacing: 6,
                children: oldPartPhotos
                    .map(
                      (x) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(x.path),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                    .toList(),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: _showOldPartSourceSheet,
                icon: const Icon(Icons.camera_alt, size: 16, color: Colors.red),
                label: const Text(
                  'Photo of OLD part',
                  style: TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: uploading ? null : _submit,
                child: uploading
                    ? const CircularProgressIndicator()
                    : Text(
                        extraLabor == 0 && needsParts
                            ? 'Request Materials Only - KES $partsEstimateTotal parts (no extra labour)'
                            : extraLabor == 0 && !needsParts
                            ? 'Select a reason to continue'
                            : 'Send Request Extra to Pay KES $extraLabor',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billRow(
    String l,
    String v, {
    bool highlight = false,
    bool highlightYellow = false,
    bool small = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: small ? 9 : 11,
            ),
          ),
          Text(
            v,
            style: GoogleFonts.montserrat(
              color: highlightYellow
                  ? FundipapColors.primaryYellow
                  : Colors.white,
              fontWeight: highlight || highlightYellow
                  ? FontWeight.w800
                  : FontWeight.w600,
              fontSize: small
                  ? 10
                  : highlightYellow
                  ? 13
                  : 11,
            ),
          ),
        ],
      ),
    );
  }
}*/
