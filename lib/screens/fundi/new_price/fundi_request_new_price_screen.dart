import 'dart:io';
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
import 'price_calc_mixin.dart';
import 'verification_section.dart';
import 'evidence_section.dart';
import 'bill_and_reason_section.dart';

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

class _FundiRequestNewPriceScreenState extends State<FundiRequestNewPriceScreen>
    with PriceCalcMixin {
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
  String? selectedAnchorPhoto;
  Rect blurRect = const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4);
  bool anchorVerified = false;
  bool verifying = false;
  String? verifyReason;

  @override
  void initState() {
    super.initState();
    addPartNeeded();
    _loadBadge();
    _pickRandomAnchor();
  }

  void _pickRandomAnchor() {
    var photos =
        widget.job['photos'] as List? ?? widget.job['images'] as List? ?? [];
    if (photos.isNotEmpty) {
      photos.shuffle();
      selectedAnchorPhoto = photos.first.toString();
      blurRect = Rect.fromLTWH(
        0.25 + (DateTime.now().millisecond % 20) / 100,
        0.25 + (DateTime.now().millisecond % 20) / 100,
        0.4,
        0.4,
      );
    }
  }

  Future<void> _loadBadge() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var r = await FundiBadgeService.getBadge(uid);
    setState(() {
      badge = r;
      fundiFeePct = r.fundiCommissionPct;
      clientFeePct = r.clientCommissionPct;
    });
  }

  void addPartNeeded() => setState(
    () => partsNeeded.add({
      'name': TextEditingController(),
      'qty': TextEditingController(text: '1'),
      'model': TextEditingController(),
      'estPrice': TextEditingController(text: '0'),
    }),
  );

  void clearParts() {
    tillCtrl.clear();
    for (var p in partsNeeded) {
      p['name']?.clear();
      p['qty']?.text = '1';
      p['model']?.clear();
      p['estPrice']?.text = '0';
    }
    if (partsNeeded.length > 1) partsNeeded = [partsNeeded.first];
  }

  Future<void> runAnchorCheck(String localPath) async {
    if (selectedAnchorPhoto == null) {
      setState(() => anchorVerified = true);
      return;
    }
    setState(() {
      verifying = true;
      anchorVerified = false;
      verifyReason = null;
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
            'clientPhotoUrl': selectedAnchorPhoto,
            'verificationPhotoUrl': verifyUrl,
            'blurRect': {
              'left': blurRect.left,
              'top': blurRect.top,
              'width': blurRect.width,
              'height': blurRect.height,
            },
          });
      final data = Map<String, dynamic>.from(res.data);
      setState(() {
        anchorVerified = data['verified'] == true;
        verifyReason = data['reason'];
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
      setState(() => verifyReason = e.toString());
    } finally {
      if (mounted) setState(() => verifying = false);
    }
  }

  Future<List<String>> uploadPhotos(List<XFile> files, String folder) async {
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

  Future<void> submit() async {
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
    if (needsLabor && extraLabor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter extra labour amount')),
      );
      return;
    }
    if (needsParts && partsEstimateTotal == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 1 part with price')),
      );
      return;
    }
    setState(() => uploading = true);
    try {
      bool hasParts = needsParts;
      var evidenceUrls = await uploadPhotos(evidencePhotos, 'evidence');
      var verificationUrls = await uploadPhotos(
        verificationPhotos,
        'verification',
      );
      var oldPartUrls = await uploadPhotos(oldPartPhotos, 'old_parts');
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
                'verified': anchorVerified,
                'reason': verifyReason,
                'anchorPhoto': selectedAnchorPhoto,
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
      ).showSnackBar(const SnackBar(content: Text('Request sent to client)')));
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
            ReasonAndBillSection(state: this),
            const SizedBox(height: 16),
            VerificationSection(state: this),
            const SizedBox(height: 16),
            EvidenceSection(state: this),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: uploading ? null : submit,
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
}
