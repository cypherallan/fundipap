import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';

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
  List<XFile> oldPartPhotos = [];
  final picker = ImagePicker();
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    _addPartNeeded();
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
    // keep one empty row so UI doesn't disappear
    if (partsNeeded.length > 1) {
      partsNeeded = [partsNeeded.first];
    }
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
    widget.job['agreedPrice'] ??
        widget.job['laborCost'] ??
        widget.job['budget'] ??
        0,
  );
  int get transport =>
      _toInt(widget.job['transportFee'] ?? widget.job['escrowTransport'] ?? 0);
  int get extraLabor => _needsLabor ? _toInt(extraLaborCtrl.text) : 0;
  int get newLaborTotal => oldLabor + extraLabor;
  int get oldClientFee => (oldLabor * 0.05).round();
  int get newClientFee => (newLaborTotal * 0.05).round();
  int get newFundiFee => (newLaborTotal * 0.05).round();
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
            'renegotiation': {
              'requested': true,
              'status': 'pending',
              'reasons': selectedReasons.toList(),
              'reasonDetails': detailsCtrl.text.trim(),
              'oldLabor': oldLabor,
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
              'oldPartPhotoUrls': oldPartUrls,
              'whoBuysParts': null,
              'createdAt': FieldValue.serverTimestamp(),
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
                    'Transport does not change. App Maintenance Cost = 5% of labour.',
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
                      // CLEAR ON DESELECT - FIX
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
                      if (!stillNeedsLabor) {
                        extraLaborCtrl.text = '0';
                      }
                      if (!stillNeedsParts) {
                        _clearParts();
                      }
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
            Text(
              'Evidence Photos',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: evidencePhotos
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
              onPressed: () async {
                var imgs = await picker.pickMultiImage(imageQuality: 60);
                if (imgs.isNotEmpty)
                  setState(() => evidencePhotos.addAll(imgs));
              },
              icon: const Icon(Icons.photo, size: 16),
              label: const Text(
                'Add site photos',
                style: TextStyle(fontSize: 11),
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
                onPressed: () async {
                  var img = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 60,
                  );
                  if (img != null) setState(() => oldPartPhotos.add(img));
                },
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
}
