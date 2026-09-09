import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';

class FundiProfile extends StatefulWidget {
  const FundiProfile({super.key});
  @override
  State<FundiProfile> createState() => _FundiProfileState();
}

class _FundiProfileState extends State<FundiProfile> {
  final _bioCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var doc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(uid)
        .get();
    if (doc.exists) {
      data = doc.data();
      _bioCtrl.text = data?['bio'] ?? '';
      _skillCtrl.text = data?['skill'] ?? '';
      _priceCtrl.text = (data?['price'] ?? '').toString();
    } else {
      // create empty doc so first upload doesn't fail
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      data = {};
    }
    setState(() => loading = false);
  }

  Future<void> _pickAndUpload(String field) async {
    var picker = ImagePicker();
    var file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return;
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var ref = FirebaseStorage.instance.ref().child(
        'fundi_docs/$uid/${field}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(file.path));
      var url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        field: FieldValue.arrayUnion([url]),
      }, SetOptions(merge: true));
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$field uploaded ✓')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _save() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      'bio': _bioCtrl.text,
      'skill': _skillCtrl.text,
      'price': int.tryParse(_priceCtrl.text) ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public profile saved ✨'),
        backgroundColor: FundipapColors.greenSuccess,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Container(
      color: const Color(0xFFF6F6F6),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advertise Yourself',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Clients see this profile when they search',
              style: GoogleFonts.inter(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Text(
              'Bio / About You',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g I am certified electrician with 5 years...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Skill & Rate',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillCtrl,
                    decoration: InputDecoration(
                      labelText: 'Skill (e.g Electrical)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Price KES',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FundipapColors.blackGray,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Update Public Profile',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            _uploadSection('Resume / CV', 'resumes', Icons.description),
            _uploadSection(
              'Certificates & Awards',
              'certificates',
              Icons.emoji_events,
            ),
            _uploadSection(
              'Past Work Photos',
              'portfolio',
              Icons.photo_library,
            ),
            const SizedBox(height: 24),
            Text(
              'Customer Feedback (Rating)',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where(
                    'fundiId',
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No reviews yet. Do jobs to get rated!',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  );
                }
                return Column(
                  children: snap.data!.docs.map((d) {
                    var r = d.data() as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text((r['clientName'] ?? 'C')[0]),
                        ),
                        title: Text(
                          r['comment'] ?? '',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        subtitle: Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              size: 12,
                              color: i < (r['rating'] ?? 5)
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _uploadSection(String title, String field, IconData icon) {
    List urls = data?[field] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _pickAndUpload(field),
              icon: const Icon(Icons.upload, size: 16),
              label: const Text('Upload'),
            ),
          ],
        ),
        if (urls.isEmpty)
          Text(
            'No $title yet',
            style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: urls
                .map<Widget>(
                  (url) => Chip(
                    label: Text('File ${urls.indexOf(url) + 1}'),
                    avatar: const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    onDeleted: () async {
                      var uid = FirebaseAuth.instance.currentUser!.uid;
                      await FirebaseFirestore.instance
                          .collection('fundis')
                          .doc(uid)
                          .update({
                            field: FieldValue.arrayRemove([url]),
                          });
                      _load();
                    },
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
