import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

mixin FundiMyJobsActionsMixin<T extends StatefulWidget> on State<T> {
  Future<void> counterAsFundi(
    DocumentReference bidRef,
    String jobId,
    double currentPrice,
  ) async {
    final ctrl = TextEditingController(text: currentPrice.toString());
    final msgCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          'Counter Offer',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New price KES (include parts)',
              ),
            ),
            TextField(
              controller: msgCtrl,
              decoration: const InputDecoration(
                labelText: 'Include part costs breakdown',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (res != true) return;
    double newPrice = double.tryParse(ctrl.text) ?? currentPrice;
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    await bidRef.collection('counterOffers').add({
      'price': newPrice,
      'by': uid,
      'byName': userDoc.data()?['username'] ?? 'Fundi',
      'message': msgCtrl.text.trim(),
      'at': FieldValue.serverTimestamp(),
    });
    await bidRef.update({
      'status': 'countered',
      'lastCounterPrice': newPrice,
      'lastCounterBy': uid,
      'lastCounterAt': FieldValue.serverTimestamp(),
    });
    var jobRef = FirebaseFirestore.instance.collection('jobs').doc(jobId);
    var jobSnap = await jobRef.get();
    var jobStatus = jobSnap.data()?['status'] ?? '';
    if (['assigned', 'site_visit', 'negotiating'].contains(jobStatus)) {
      await jobRef.update({
        'status': 'negotiating',
        'renegotiation.status': 'countered_by_fundi',
        'renegotiation.newPrice': newPrice,
        'renegotiation.reason': msgCtrl.text.trim(),
        'renegotiation.lastCounterBy': uid,
        'renegotiation.lastCounterAt': FieldValue.serverTimestamp(),
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_fundi',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await jobRef.update({
        'status': 'negotiating',
        'priceHistory': FieldValue.arrayUnion([
          {
            'price': newPrice,
            'by': uid,
            'type': 'counter_fundi',
            'at': DateTime.now().toIso8601String(),
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> markSiteVisited(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'siteVisitDone': true,
      'siteVisitAt': FieldValue.serverTimestamp(),
      'status': 'site_visit',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestNewPriceAfterVisit(String jobId) async {
    final priceCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final picker = ImagePicker();
    List<XFile> pickedImages = [];
    bool isUploading = false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            'Request New Price After Site Visit',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'New total price KES (labor+parts)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'Why more? Describe site findings + parts needed',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Site Photos (optional for now)',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (pickedImages.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: pickedImages
                        .map(
                          (x) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(x.path),
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      setDialog(() => pickedImages.remove(x)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text(
                    pickedImages.isEmpty
                        ? 'Add Photos (Optional)'
                        : 'Add More Photos',
                  ),
                  onPressed: () async {
                    final imgs = await picker.pickMultiImage(imageQuality: 70);
                    if (imgs.isNotEmpty)
                      setDialog(() => pickedImages.addAll(imgs));
                  },
                ),
                if (isUploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 4),
                  Text(
                    pickedImages.isEmpty
                        ? 'Sending...'
                        : 'Uploading ${pickedImages.length} photos...',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (priceCtrl.text.trim().isEmpty ||
                          reasonCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Price and reason required'),
                          ),
                        );
                        return;
                      }
                      setDialog(() => isUploading = true);
                      List<String> urls = [];
                      try {
                        if (pickedImages.isNotEmpty) {
                          for (var f in pickedImages) {
                            final ref = FirebaseStorage.instance.ref().child(
                              'jobs/$jobId/siteVisit/${DateTime.now().millisecondsSinceEpoch}_${f.name}',
                            );
                            await ref.putFile(File(f.path));
                            urls.add(await ref.getDownloadURL());
                          }
                        }
                        Navigator.pop(ctx, {
                          'price': priceCtrl.text.trim(),
                          'reason': reasonCtrl.text.trim(),
                          'photos': urls,
                        });
                      } catch (e) {
                        setDialog(() => isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Upload failed, sending without photos: $e',
                            ),
                          ),
                        );
                        Navigator.pop(ctx, {
                          'price': priceCtrl.text.trim(),
                          'reason': reasonCtrl.text.trim(),
                          'photos': [],
                        });
                      }
                    },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    double newPrice = double.tryParse(result['price']) ?? 0;
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'renegotiation': {
        'requested': true,
        'newPrice': newPrice,
        'reason': result['reason'],
        'photos': result['photos'],
        'status': 'pending',
        'requestedBy': FirebaseAuth.instance.currentUser!.uid,
        'at': FieldValue.serverTimestamp(),
      },
      'siteVisitDone': true,
      'siteVisitFindings': result['reason'],
      'siteVisitPhotos': result['photos'],
      'siteVisitAt': FieldValue.serverTimestamp(),
      'status': 'site_visit',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'in_progress',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addParts(String jobId) async {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Part Cost'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Part name'),
            ),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cost KES'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != true) return;
    double cost = double.tryParse(costCtrl.text) ?? 0;
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'parts': FieldValue.arrayUnion([
        {
          'name': nameCtrl.text,
          'cost': cost,
          'at': DateTime.now().toIso8601String(),
        },
      ]),
    });
  }

  Future<void> markCompletedFundi(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'fundiConfirmedComplete': true,
      'status': 'pending_completion',
      'fundiCompletedAt': FieldValue.serverTimestamp(),
    });
  }
}
