import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_theme.dart';

class FundiAddPartReceiptScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> job;
  const FundiAddPartReceiptScreen({
    super.key,
    required this.jobId,
    required this.job,
  });

  @override
  State<FundiAddPartReceiptScreen> createState() =>
      _FundiAddPartReceiptScreenState();
}

class _FundiAddPartReceiptScreenState extends State<FundiAddPartReceiptScreen> {
  final partCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final shopCtrl = TextEditingController();
  final List<XFile> _images = [];
  bool uploading = false;
  final picker = ImagePicker();

  Future<void> _pick() async {
    final picked = await picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) setState(() => _images.addAll(picked));
  }

  Future<void> _pickCamera() async {
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _images.add(picked));
  }

  Future<void> _upload() async {
    if (partCtrl.text.isEmpty || costCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter part name & cost')));
      return;
    }
    setState(() => uploading = true);
    try {
      List<String> urls = [];
      // PHOTOS OPTIONAL FOR SPARK PLAN
      if (_images.isNotEmpty) {
        for (var x in _images) {
          String path =
              'jobs/${widget.jobId}/receipts/${DateTime.now().millisecondsSinceEpoch}_${x.name}';
          var ref = FirebaseStorage.instance.ref().child(path);
          await ref.putFile(File(x.path));
          urls.add(await ref.getDownloadURL());
        }
      }
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .collection('parts')
          .add({
            'partName': partCtrl.text.trim(),
            'cost': int.tryParse(costCtrl.text) ?? 0,
            'shopName': shopCtrl.text.trim(),
            'photoUrls': urls, // empty if Spark plan - no storage used
            'hasPhotos': urls.isNotEmpty,
            'fundiId': FirebaseAuth.instance.currentUser!.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'pending_approval',
          });
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
            'hasParts': true,
            'partsUpdatedAt': FieldValue.serverTimestamp(),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Part added ✓')));
      Navigator.pop(context);
    } catch (e) {
      // If storage fails on Spark, still save without photos
      if (e.toString().contains('storage') || e.toString().contains('quota')) {
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .collection('parts')
            .add({
              'partName': partCtrl.text.trim(),
              'cost': int.tryParse(costCtrl.text) ?? 0,
              'shopName': shopCtrl.text.trim(),
              'photoUrls': [],
              'hasPhotos': false,
              'fundiId': FirebaseAuth.instance.currentUser!.uid,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'pending_approval',
            });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Part saved without photos (Spark plan)'),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Part Receipt',
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
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upload shop receipt photo for ${widget.job['title']}',
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: partCtrl,
              decoration: InputDecoration(
                labelText: 'Part Name (e.g. Tap, Pipe, Cement)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cost KES',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: shopCtrl,
              decoration: InputDecoration(
                labelText: 'Shop Name (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Receipt Photos (Optional - will be required after upgrade)',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _images.isEmpty
                ? Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Center(
                      child: Text(
                        'No photos yet',
                        style: GoogleFonts.inter(color: Colors.black45),
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _images
                        .map(
                          (x) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(x.path),
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: InkWell(
                                  onTap: () =>
                                      setState(() => _images.remove(x)),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Show previous receipts
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(widget.jobId)
                  .collection('parts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty)
                  return const SizedBox();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous Receipts',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...snap.data!.docs.map((d) {
                      var data = d.data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${data['partName']} - KES ${data['cost']}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Status: ${data['status']}',
                            style: GoogleFonts.inter(fontSize: 10),
                          ),
                          trailing: data['photoUrls'] != null
                              ? Image.network(
                                  (data['photoUrls'] as List).first,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.primaryYellow,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: uploading ? null : _upload,
                child: uploading
                    ? const CircularProgressIndicator()
                    : Text(
                        'Submit Receipt',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
