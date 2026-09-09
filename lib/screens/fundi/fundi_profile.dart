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
  final _priceCtrl = TextEditingController();
  final _otherProfCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();

  Map<String, dynamic>? data;
  Map<String, dynamic>? userData;
  bool loading = true;
  bool uploadingPhoto = false;

  String selectedProfession = 'Carpentry';
  List<String> selectedSkills = [];
  int profilePct = 0;

  final professions = [
    'Carpentry',
    'Cleaning',
    'Dishwasher Installation',
    'Electricals/Electronics Repair',
    'Electronics Repair',
    'Gardening',
    'Masonry',
    'Mechanic',
    'Painting',
    'Plumbing',
    'TV Installation',
    'Washing Machine Installation',
    'Washing Machine Repair',
    'Welding',
    'Other',
  ];

  final allSkills = [
    'Carpentry',
    'Cleaning',
    'Dishwasher Installation',
    'Electricals/Electronics Repair',
    'Electronics Repair',
    'Gardening',
    'Masonry',
    'Mechanic',
    'Painting',
    'Plumbing',
    'TV Installation',
    'Washing Machine Installation',
    'Washing Machine Repair',
    'Welding',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var uid = FirebaseAuth.instance.currentUser!.uid;
    var fundiDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(uid)
        .get();
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    data = fundiDoc.data() ?? {};
    userData = userDoc.data() ?? {};
    var combined = {...?userData, ...?data};

    _bioCtrl.text = combined['bio'] ?? '';
    _priceCtrl.text = (combined['price'] ?? '').toString();
    selectedProfession =
        combined['profession'] ?? combined['skill'] ?? 'Carpentry';
    if (!professions.contains(selectedProfession)) {
      // if custom profession, set to Other and fill text
      if (selectedProfession.isNotEmpty && selectedProfession != 'General') {
        _otherProfCtrl.text = selectedProfession;
        selectedProfession = 'Other';
      }
    }
    selectedSkills = List<String>.from(combined['otherSkills'] ?? []);
    _keywordCtrl.text = combined['searchKeyword'] ?? '';

    // calc %
    int pct = 0;
    if ((combined['name'] ?? '').toString().length > 2) pct += 10;
    if ((combined['profession'] ?? '').toString().isNotEmpty) pct += 15;
    if ((combined['bio'] ?? '').toString().length > 20) pct += 20;
    if ((combined['price'] ?? 0) != 0) pct += 10;
    if (combined['photoUrl'] != null) pct += 15;
    if ((combined['phone'] ?? '').toString().length > 5) pct += 5;
    if ((combined['resumes'] as List?)?.isNotEmpty ?? false) pct += 7;
    if ((combined['certificates'] as List?)?.isNotEmpty ?? false) pct += 8;
    if ((combined['portfolio'] as List?)?.isNotEmpty ?? false) pct += 5;
    profilePct = pct.clamp(0, 100);

    setState(() => loading = false);
  }

  Future<void> _changePhoto() async {
    var picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => uploadingPhoto = true);
    try {
      var uid = FirebaseAuth.instance.currentUser!.uid;
      var ref = FirebaseStorage.instance.ref().child('fundis/$uid/profile.jpg');
      await ref.putFile(File(picked.path));
      var url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'photoUrl': url,
      });
      await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
        'photoUrl': url,
      }, SetOptions(merge: true));
      await _load();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo updated +15%')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => uploadingPhoto = false);
    }
  }

  Future<void> _pickAndUpload(String field) async {
    var file = await ImagePicker().pickImage(
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
    String finalProf = selectedProfession == 'Other'
        ? _otherProfCtrl.text.trim()
        : selectedProfession;
    String finalKeyword = selectedProfession == 'Other'
        ? _keywordCtrl.text.trim().toLowerCase()
        : finalProf.toLowerCase();

    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      'profession': finalProf,
      'skill': finalProf,
      'searchKeyword': finalKeyword,
      'otherSkills': selectedSkills,
      'bio': _bioCtrl.text.trim(),
      'price': int.tryParse(_priceCtrl.text) ?? 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'profession': finalProf,
      'skill': finalProf,
      'searchKeyword': finalKeyword,
      'otherSkills': selectedSkills,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public profile saved ✨'),
        backgroundColor: FundipapColors.greenSuccess,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    var combined = {...?userData, ...?data};
    bool isOther = selectedProfession == 'Other';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP PROFILE PHOTO + COMPLETION
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: CircularProgressIndicator(
                          value: profilePct / 100,
                          strokeWidth: 4,
                          backgroundColor: Colors.black12,
                          valueColor: AlwaysStoppedAnimation(
                            profilePct == 100
                                ? FundipapColors.greenSuccess
                                : FundipapColors.primaryYellow,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        left: 5,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: FundipapColors.primaryYellow,
                          backgroundImage: combined['photoUrl'] != null
                              ? NetworkImage(combined['photoUrl'])
                              : null,
                          child: combined['photoUrl'] == null
                              ? Text(
                                  (combined['name'] ?? 'F')[0].toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 30,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _changePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: FundipapColors.blackGray,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (uploadingPhoto)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    combined['name'] ?? 'Fundi',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${profilePct}% Complete ${profilePct == 100 ? '• VERIFIED' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: profilePct == 100
                          ? FundipapColors.greenSuccess
                          : Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: _changePhoto,
                    child: Text(
                      combined['photoUrl'] == null
                          ? 'Set Profile Photo (+15%)'
                          : 'Change Profile Photo',
                      style: GoogleFonts.montserrat(
                        color: FundipapColors.primaryYellow,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: profilePct / 100,
              color: profilePct == 100
                  ? FundipapColors.greenSuccess
                  : FundipapColors.primaryYellow,
              backgroundColor: Colors.black12,
            ),
            const SizedBox(height: 20),
            Text(
              'Advertise Yourself',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              'Clients see this when they search',
              style: GoogleFonts.inter(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // PRIMARY PROFESSION
            Text(
              'Primary Profession *',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: professions.contains(selectedProfession)
                  ? selectedProfession
                  : 'Other',
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: professions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => selectedProfession = v!),
            ),
            if (isOther) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherProfCtrl,
                decoration: InputDecoration(
                  labelText: 'Your profession *',
                  hintText: 'e.g. Washing Machine Repair',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keywordCtrl,
                decoration: InputDecoration(
                  labelText: 'Keyword for search *',
                  hintText: 'e.g. washing machine',
                  helperText: 'This keyword decides which jobs show first',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // OTHER SKILLS MULTI
            Text(
              'Other skills you also do',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allSkills
                  .where(
                    (s) =>
                        s !=
                        (isOther ? _otherProfCtrl.text : selectedProfession),
                  )
                  .map((skill) {
                    bool sel = selectedSkills.contains(skill);
                    return FilterChip(
                      label: Text(
                        skill,
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      selected: sel,
                      onSelected: (v) {
                        setState(() {
                          if (v)
                            selectedSkills.add(skill);
                          else
                            selectedSkills.remove(skill);
                        });
                      },
                    );
                  })
                  .toList(),
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
                hintText:
                    'e.g I install & repair washing machines, dishwashers, TVs. 5 years experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate per job',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
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
