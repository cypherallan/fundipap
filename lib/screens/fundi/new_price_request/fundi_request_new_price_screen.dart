import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';
import '../services/fundi_badge_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'price_request_reasons.dart';
import 'part_needed.dart';
import 'price_calculator.dart';
import 'photo_uploader.dart';
import 'anchor_verifier.dart';
import 'current_price_card.dart';
import 'reason_chips.dart';
import 'extra_labor_section.dart';
import 'parts_needed_section.dart';
import 'bill_summary_card.dart';
import 'verification_section.dart';
import 'evidence_section.dart';
import 'old_part_section.dart';

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
  Set<String> selectedReasons = {};
  final detailsCtrl = TextEditingController();
  final extraLaborCtrl = TextEditingController(text: '0');
  final tillCtrl = TextEditingController();
  List<PartNeeded> partsNeeded = [];
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
  bool _verifying = false;
  String? _verifyReason;

  @override
  void initState() {
    super.initState();
    _addPartNeeded();
    _loadBadge();
    _pickRandomAnchor();
  }

  @override
  void dispose() {
    detailsCtrl.dispose();
    extraLaborCtrl.dispose();
    tillCtrl.dispose();
    for (final p in partsNeeded) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _pickRandomAnchor() async {
    var photos =
        widget.job['photos'] as List? ?? widget.job['images'] as List? ?? [];
    if (photos.isEmpty) return;
    photos.shuffle();
    setState(() {
      _selectedAnchorPhoto = photos.first.toString();
      _blurRect = const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4);
    });
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('getVisibleBlurRect')
          .call({'clientPhotoUrl': _selectedAnchorPhoto});
      final d = Map<String, dynamic>.from(res.data);
      if (mounted) {
        setState(
          () => _blurRect = Rect.fromLTWH(
            (d['left'] as num).toDouble(),
            (d['top'] as num).toDouble(),
            (d['width'] as num).toDouble(),
            (d['height'] as num).toDouble(),
          ),
        );
      }
    } catch (_) {
      // keep center fallback
    }
  }

  bool get _hasValidVerification =>
      verificationPhotos.isNotEmpty && _anchorVerified;

  Future<void> _loadBadge() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final r = await FundiBadgeService.getBadge(uid);
    setState(() {
      badge = r;
      fundiFeePct = r.fundiCommissionPct;
      clientFeePct = r.clientCommissionPct;
    });
  }

  void _addPartNeeded() {
    setState(() => partsNeeded.add(PartNeeded()));
  }

  void _clearParts() {
    tillCtrl.clear();
    for (final p in partsNeeded) {
      p.name.clear();
      p.qty.text = '1';
      p.model.clear();
      p.estPrice.text = '0';
    }
    if (partsNeeded.length > 1) {
      for (var i = 1; i < partsNeeded.length; i++) {
        partsNeeded[i].dispose();
      }
      partsNeeded = [partsNeeded.first];
    }
  }

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
      final data = await AnchorVerifier.verify(
        jobId: widget.jobId,
        clientPhotoUrl: _selectedAnchorPhoto,
        localPath: localPath,
        blurRect: _blurRect,
      );
      setState(() {
        _anchorVerified = data['verified'] == true;
        _verifyReason = data['reason'];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['verified'] == true
                  ? 'Verified ${data['score']}%: ${data['reason']}'
                  : 'FAILED: ${data['reason']}',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _verifyReason = e.toString());
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
                final img = await picker.pickImage(
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
                final img = await picker.pickImage(
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
                final imgs = await picker.pickMultiImage(imageQuality: 60);
                if (imgs.isNotEmpty) {
                  setState(() => evidencePhotos.addAll(imgs));
                }
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
                final img = await picker.pickImage(
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
                final img = await picker.pickImage(
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

  Future<void> _submit() async {
    if (selectedReasons.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select at least 1 reason')));
      return;
    }
    if (detailsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Explain why price increased')),
      );
      return;
    }

    final needsLabor = PriceRequestReasons.needsLabor(selectedReasons);
    final needsParts = PriceRequestReasons.needsParts(selectedReasons);
    final extraLabor = int.tryParse(extraLaborCtrl.text) ?? 0;

    if (needsLabor && extraLabor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter extra labour amount')),
      );
      return;
    }

    final calc = PriceCalculator(
      job: widget.job,
      fundiFeePct: fundiFeePct,
      clientFeePct: clientFeePct,
      extraLabor: extraLabor,
      needsLabor: needsLabor,
      needsParts: needsParts,
      partsNeeded: partsNeeded,
    );

    if (needsParts && calc.partsEstimateTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 1 part with price')),
      );
      return;
    }

    setState(() => uploading = true);
    try {
      final evidenceUrls = await PhotoUploader.upload(
        evidencePhotos,
        widget.jobId,
        'evidence',
      );
      final verificationUrls = await PhotoUploader.upload(
        verificationPhotos,
        widget.jobId,
        'verification',
      );
      final oldPartUrls = await PhotoUploader.upload(
        oldPartPhotos,
        widget.jobId,
        'old_parts',
      );

      final partsNeededData = needsParts
          ? partsNeeded.where((p) => p.hasName).map((p) => p.toMap()).toList()
          : <Map>[];

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'originalLaborCost':
                widget.job['originalLaborCost'] ?? calc.oldLabor,
            'laborCost': calc.oldLabor,
            'renegotiation': {
              'requested': true,
              'status': 'pending',
              'reasons': selectedReasons.toList(),
              'reasonDetails': detailsCtrl.text.trim(),
              'oldLabor': calc.oldLabor,
              'originalLabor': widget.job['originalLaborCost'] ?? calc.oldLabor,
              'extraLabor': calc.effectiveExtraLabor,
              'newLaborTotal': calc.newLaborTotal,
              'pendingLabor': calc.effectiveExtraLabor,
              'oldClientAppFee': calc.oldClientFee,
              'newClientAppFee': calc.newClientFee,
              'newFundiAppFee': calc.newFundiFee,
              'transportFee': calc.transport,
              'oldTotalClientPays': calc.oldTotalClient,
              'newTotalClientPays': calc.newTotalClient,
              'newFundiReceives': calc.newFundiReceives,
              'extraToLock': calc.extraToLock,
              'partsNeeded': partsNeededData,
              'partsEstimateTotal': needsParts ? calc.partsEstimateTotal : 0,
              'partsPaymentDestination': 'shop_direct',
              'tillNumber': needsParts ? tillCtrl.text.trim() : '',
              'evidencePhotoUrls': evidenceUrls,
              'verificationPhotoUrls': verificationUrls,
              'oldPartPhotoUrls': oldPartUrls,
              'hasVerificationPhotos': verificationPhotos.isNotEmpty,
              'hasEvidencePhotos': evidencePhotos.isNotEmpty,
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
      ).showSnackBar(const SnackBar(content: Text('Request sent to client')));
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
    final needsLabor = PriceRequestReasons.needsLabor(selectedReasons);
    final needsParts = PriceRequestReasons.needsParts(selectedReasons);
    final needsReplacement = PriceRequestReasons.needsReplacement(
      selectedReasons,
    );

    final calc = PriceCalculator(
      job: widget.job,
      fundiFeePct: fundiFeePct,
      clientFeePct: clientFeePct,
      extraLabor: int.tryParse(extraLaborCtrl.text) ?? 0,
      needsLabor: needsLabor,
      needsParts: needsParts,
      partsNeeded: partsNeeded,
    );

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
            CurrentPriceCard(
              calc: calc,
              badge: badge,
              clientFeePct: clientFeePct,
              fundiFeePct: fundiFeePct,
            ),
            const SizedBox(height: 16),
            ReasonChips(
              selected: selectedReasons,
              onChanged: (next) {
                setState(() {
                  selectedReasons = next;
                  if (!PriceRequestReasons.needsLabor(next)) {
                    extraLaborCtrl.text = '0';
                  }
                  if (!PriceRequestReasons.needsParts(next)) {
                    _clearParts();
                  }
                });
              },
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
            if (needsLabor)
              ExtraLaborSection(
                controller: extraLaborCtrl,
                onChanged: () => setState(() {}),
              ),
            if (needsParts)
              PartsNeededSection(
                parts: partsNeeded,
                tillCtrl: tillCtrl,
                onAdd: _addPartNeeded,
                onRemove: (idx) {
                  setState(() {
                    partsNeeded[idx].dispose();
                    partsNeeded.removeAt(idx);
                  });
                },
                onChanged: () => setState(() {}),
              ),
            const SizedBox(height: 16),
            BillSummaryCard(
              calc: calc,
              needsLabor: needsLabor,
              needsParts: needsParts,
              partsNeeded: partsNeeded,
            ),
            const SizedBox(height: 16),
            VerificationSection(
              selectedAnchorPhoto: _selectedAnchorPhoto,
              blurRect: _blurRect,
              verificationPhotos: verificationPhotos,
              verifying: _verifying,
              anchorVerified: _anchorVerified,
              verifyReason: _verifyReason,
              onTakePhoto: _showVerificationSourceSheet,
              hasValidVerification: _hasValidVerification,
            ),
            const SizedBox(height: 16),
            EvidenceSection(
              evidencePhotos: evidencePhotos,
              onAdd: _showEvidenceSourceSheet,
              onRemove: (x) => setState(() => evidencePhotos.remove(x)),
            ),
            if (needsReplacement)
              OldPartSection(
                oldPartPhotos: oldPartPhotos,
                onAdd: _showOldPartSourceSheet,
              ),
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
                        calc.effectiveExtraLabor == 0 && needsParts
                            ? 'Request Materials Only - KES ${calc.partsEstimateTotal} parts (no extra labour)'
                            : calc.effectiveExtraLabor == 0 && !needsParts
                            ? 'Select a reason to continue'
                            : 'Send Request Extra to Pay KES ${calc.effectiveExtraLabor}',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
