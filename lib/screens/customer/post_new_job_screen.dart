import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/location_service.dart';

class PostNewJobScreen extends StatefulWidget {
  final String? jobId; // if set = EDIT MODE
  final Map<String, dynamic>? existingJob;
  const PostNewJobScreen({super.key, this.jobId, this.existingJob});
  @override
  State<PostNewJobScreen> createState() => _PostNewJobScreenState();
}

class _PostNewJobScreenState extends State<PostNewJobScreen> {
  final titleC = TextEditingController();
  final descC = TextEditingController();
  final budgetC = TextEditingController();
  String category = 'electrical';
  List<File> photos = []; // new picked
  List<String> existingPhotos = []; // urls from firestore
  bool loading = false;

  bool get isEdit => widget.jobId != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingJob != null) {
      var j = widget.existingJob!;
      titleC.text = j['title'] ?? '';
      descC.text = j['description'] ?? '';
      budgetC.text = (j['budget'] ?? j['budgetMin'] ?? '').toString();
      category = j['category'] ?? 'electrical';
      existingPhotos = List<String>.from(j['photos'] ?? j['images'] ?? []);
    }
  }

  Future<void> pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() => photos.addAll(picked.map((e) => File(e.path))));
    }
  }

  Future<void> submit() async {
    if (titleC.text.isEmpty || descC.text.isEmpty || budgetC.text.isEmpty)
      return;
    setState(() => loading = true);
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      var uData = userDoc.data() ?? {};
      var pos = await LocationService.determinePosition(context);

      // upload only new files
      List<String> newUrls = [];
      for (var f in photos) {
        var ref = FirebaseStorage.instance.ref().child(
          'jobs/${uid}_${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last}',
        );
        await ref.putFile(f);
        newUrls.add(await ref.getDownloadURL());
      }
      List<String> allPhotos = [...existingPhotos, ...newUrls];

      if (isEdit) {
        // EDIT - update same doc, no new doc
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .update({
              'title': titleC.text.trim(),
              'description': descC.text.trim(),
              'category': category,
              'budget': int.tryParse(budgetC.text) ?? 1500,
              'offeredPrice': int.tryParse(budgetC.text) ?? 1500,
              'budgetMin': int.tryParse(budgetC.text) ?? 1500,
              'photos': allPhotos,
              'images': allPhotos,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // NEW
        await FirebaseFirestore.instance.collection('jobs').add({
          'customerId': uid,
          'clientId': uid,
          'customerName': uData['name'] ?? 'Client',
          'customerUsername': uData['username'] ?? uData['name'] ?? 'Client',
          'clientUsername': uData['username'] ?? uData['name'] ?? 'Client',
          'title': titleC.text.trim(),
          'description': descC.text.trim(),
          'category': category,
          'budget': int.tryParse(budgetC.text) ?? 1500,
          'offeredPrice': int.tryParse(budgetC.text) ?? 1500,
          'budgetMin': int.tryParse(budgetC.text) ?? 1500,
          'budgetMax': null,
          'location': 'Kisumu',
          'lat': pos?.latitude,
          'lng': pos?.longitude,
          'photos': allPhotos,
          'images': allPhotos,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Job' : 'Post Job',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleC,
              decoration: const InputDecoration(
                labelText: 'Job Title e.g Wiring fix Manyatta',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: category,
              items: [
                'electrical',
                'plumbing',
                'carpentry',
                'masonry',
                'painting',
                'welding',
                'mechanic',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descC,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'How much you offer? KES',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: pickPhotos,
              icon: const Icon(Icons.photo),
              label: Text(
                existingPhotos.isEmpty && photos.isEmpty
                    ? 'Add Photos'
                    : '${existingPhotos.length + photos.length} photos',
              ),
            ),
            if (existingPhotos.isNotEmpty || photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...existingPhotos.map(
                      (url) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => existingPhotos.remove(url)),
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
                    ),
                    ...photos.map(
                      (f) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              f,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => setState(() => photos.remove(f)),
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
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: loading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isEdit ? 'SAVE CHANGES' : 'POST JOB',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
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
