import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../data/job_taxonomy.dart';

class FundiProfile extends StatefulWidget {
  const FundiProfile({super.key});
  @override
  State<FundiProfile> createState() => _FundiProfileState();
}

class _FundiProfileState extends State<FundiProfile> {
  final _bioCtrl = TextEditingController();
  final _otherProfCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _expCtrl = TextEditingController();

  Map<String, dynamic>? data;
  Map<String, dynamic>? userData;
  bool loading = true;
  bool uploadingPhoto = false;

  String selectedCategoryId = 'plumbing_waterworks';
  List<String> selectedCategoryIds = []; // other categories fundi can do
  List<String> selectedSubcategoryIds = [];
  int profilePct = 0;

  // Helper to get category by id
  Map<String, dynamic> get selectedCategory =>
      FundiTaxonomy.categories.firstWhere(
        (c) => c['id'] == selectedCategoryId,
        orElse: () => FundiTaxonomy.categories[0],
      );
  List get subcategories => selectedCategory['subcategories'] as List;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _mapOldProfessionToCategoryId(String oldProf) {
    var lower = oldProf.toLowerCase();
    if (lower.contains('plumb')) return 'plumbing_waterworks';
    if (lower.contains('electrical') || lower.contains('electrics'))
      return 'electrical';
    if (lower.contains('washing') ||
        lower.contains('fridge') ||
        lower.contains('appliance') ||
        lower.contains('cooker'))
      return 'appliance_repair';
    if (lower.contains('carpentry') || lower.contains('carpenter'))
      return 'carpentry_joinery';
    if (lower.contains('weld')) return 'welding_fabrication';
    if (lower.contains('mechanic') ||
        lower.contains('car') ||
        lower.contains('automotive'))
      return 'automotive';
    if (lower.contains('tv') || lower.contains('electronics'))
      return 'electronics_repair';
    if (lower.contains('boda') ||
        lower.contains('motorcycle') ||
        lower.contains('tuk'))
      return 'motorcycle_boda';
    if (lower.contains('masonry') || lower.contains('building'))
      return 'masonry_building';
    if (lower.contains('paint')) return 'painting_decoration';
    if (lower.contains('roof') || lower.contains('gutter'))
      return 'roofing_guttering';
    if (lower.contains('tile') || lower.contains('terrazzo'))
      return 'tiling_flooring';
    if (lower.contains('ac') || lower.contains('hvac')) return 'hvac';
    if (lower.contains('solar') || lower.contains('inverter'))
      return 'solar_renewable';
    if (lower.contains('cctv') || lower.contains('security'))
      return 'security_systems';
    if (lower.contains('glass') ||
        lower.contains('aluminium') ||
        lower.contains('aluminum'))
      return 'glass_aluminum';
    if (lower.contains('gypsum') || lower.contains('ceiling'))
      return 'gypsum_ceiling';
    if (lower.contains('waterproof')) return 'waterproofing';
    if (lower.contains('borehole') || lower.contains('pump'))
      return 'borehole_pump';
    if (lower.contains('generator')) return 'generator_power';
    if (lower.contains('garden') || lower.contains('landscap'))
      return 'landscaping_gardening';
    if (lower.contains('clean')) return 'cleaning_laundry';
    if (lower.contains('pest') || lower.contains('fumigation'))
      return 'pest_control';
    if (lower.contains('locksmith') || lower.contains('key'))
      return 'locksmith';
    return 'plumbing_waterworks';
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
    _expCtrl.text =
        (combined['experienceYears'] ?? combined['experience'] ?? '')
            .toString();

    // Map old profession string to new 24 categories
    String oldProf =
        combined['profession'] ??
        combined['skill'] ??
        combined['primaryCategoryName'] ??
        'Plumbing';
    if (combined['primaryCategoryId'] != null) {
      selectedCategoryId = combined['primaryCategoryId'];
    } else {
      selectedCategoryId = _mapOldProfessionToCategoryId(oldProf);
    }
    if (!FundiTaxonomy.categories.any((c) => c['id'] == selectedCategoryId)) {
      selectedCategoryId = 'plumbing_waterworks';
    }

    // Load other categories
    List<String> catIds = List<String>.from(
      combined['categoryIds'] ?? combined['categories'] ?? [],
    );
    if (catIds.isEmpty && combined['otherSkills'] != null) {
      // migrate old otherSkills strings to categoryIds
      var oldOthers = List<String>.from(combined['otherSkills']);
      for (var s in oldOthers) {
        catIds.add(_mapOldProfessionToCategoryId(s));
      }
    }
    // Remove primary from others and dedup
    catIds = catIds.toSet().where((id) => id != selectedCategoryId).toList();
    selectedCategoryIds = catIds;

    selectedSubcategoryIds = List<String>.from(
      combined['subcategoryIds'] ?? [],
    );

    _keywordCtrl.text =
        combined['searchKeyword'] ?? selectedCategory['slug'] ?? '';
    _otherProfCtrl.text = '';

    int pct = 0;
    if ((combined['name'] ?? '').toString().length > 2) pct += 10;
    if ((combined['profession'] ?? combined['primaryCategoryId'] ?? '')
        .toString()
        .isNotEmpty)
      pct += 15;
    if ((combined['bio'] ?? '').toString().length > 20) pct += 20;
    if ((combined['bio'] ?? '').toString().length > 20) pct += 30;
    if (combined['photoUrl'] != null) pct += 15;
    if ((combined['phone'] ?? '').toString().length > 5) pct += 5;
    if ((combined['resumes'] as List?)?.isNotEmpty ?? false) pct += 7;
    if ((combined['certificates'] as List?)?.isNotEmpty ?? false) pct += 8;
    if ((combined['portfolio'] as List?)?.isNotEmpty ?? false) pct += 5;
    profilePct = pct.clamp(0, 100);
    if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Photo updated +15%')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (!mounted) return;
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
      if (!mounted) return;
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
    var cat = selectedCategory;
    String finalKeyword = _keywordCtrl.text.trim().isEmpty
        ? (cat['slug'] as String)
        : _keywordCtrl.text.trim().toLowerCase();

    List<String> allCatIds = [
      selectedCategoryId,
      ...selectedCategoryIds,
    ].toSet().toList();

    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      // NEW 24 CATEGORIES SYSTEM
      'primaryCategoryId': selectedCategoryId,
      'primaryCategoryName': cat['name'],
      'primaryCategorySlug': cat['slug'],
      'categoryIds': allCatIds,
      'categories': allCatIds, // backward compat
      'subcategoryIds': selectedSubcategoryIds,
      // OLD FIELDS - kept for backward compat with old job matching
      'profession': cat['name'],
      'skill': cat['name'],
      'searchKeyword': finalKeyword,
      'otherSkills': selectedCategoryIds.map((id) {
        try {
          return FundiTaxonomy.categories.firstWhere(
            (c) => c['id'] == id,
          )['name'];
        } catch (_) {
          return id;
        }
      }).toList(),
      'bio': _bioCtrl.text.trim(),
      'experienceYears': int.tryParse(_expCtrl.text) ?? _expCtrl.text,
      'experience': _expCtrl.text,
      'available': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'jobsCompleted': data?['jobsCompleted'] ?? 0,
      'fraudCount': data?['fraudCount'] ?? 0,
      'averageRating': data?['averageRating'] ?? data?['rating'] ?? 4.5,
      'ratingCount': data?['ratingCount'] ?? 0,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'profession': cat['name'],
      'skill': cat['name'],
      'primaryCategoryId': selectedCategoryId,
      'categoryIds': allCatIds,
      'searchKeyword': finalKeyword,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public profile saved with 24-category system ✨'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    var combined = {...?userData, ...?data};
    var jobsDone = combined['jobsCompleted'] ?? 0;
    var rating = (combined['averageRating'] ?? combined['rating'] ?? 4.5)
        .toDouble();
    var fraud = combined['fraudCount'] ?? 0;
    var ratingCount = combined['ratingCount'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            Row(
              children: [
                _stat('$jobsDone', 'Jobs Done'),
                const SizedBox(width: 8),
                _stat('${rating.toStringAsFixed(1)}★ ($ratingCount)', 'Rating'),
                const SizedBox(width: 8),
                _stat('$fraud', 'Fraud Cases'),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 18, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Now 24 categories. Your profile matches jobs by categoryId, not text. Select primary + other categories you can do.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Primary Profession * (24 Categories)',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedCategoryId,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: FundiTaxonomy.categories.map((c) {
                bool isTop = c['isTop6'] == true;
                return DropdownMenuItem(
                  value: c['id'] as String,
                  child: Row(
                    children: [
                      Text(
                        isTop ? '⭐ ' : '',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          c['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isTop
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                selectedCategoryId = v!;
                selectedSubcategoryIds =
                    []; // reset subcategories when primary changes
              }),
            ),
            const SizedBox(height: 12),
            if (subcategories.isNotEmpty) ...[
              Text(
                'What you do inside ${selectedCategory['name']} - Select sub-services',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: subcategories.map((s) {
                  var ss = s as Map<String, dynamic>;
                  bool sel = selectedSubcategoryIds.contains(ss['id']);
                  return FilterChip(
                    label: Text(
                      ss['name'] as String,
                      style: GoogleFonts.inter(fontSize: 11),
                    ),
                    selected: sel,
                    selectedColor: FundipapColors.primaryYellow.withOpacity(
                      0.4,
                    ),
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          selectedSubcategoryIds.add(ss['id']);
                        } else {
                          selectedSubcategoryIds.remove(ss['id']);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Years of Experience',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _expCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'e.g. 5',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Other Categories You Also Do (24)',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Clients searching these categories will also see you',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: FundiTaxonomy.categories
                  .where((c) => c['id'] != selectedCategoryId)
                  .map((c) {
                    bool sel = selectedCategoryIds.contains(c['id']);
                    bool isTop = c['isTop6'] == true;
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTop)
                            const Text('⭐ ', style: TextStyle(fontSize: 10)),
                          Text(
                            c['name'] as String,
                            style: GoogleFonts.inter(fontSize: 11),
                          ),
                        ],
                      ),
                      selected: sel,
                      selectedColor: FundipapColors.primaryYellow.withOpacity(
                        0.3,
                      ),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            selectedCategoryIds.add(c['id'] as String);
                          } else {
                            selectedCategoryIds.remove(c['id']);
                          }
                        });
                      },
                    );
                  })
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Search Keyword',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _keywordCtrl,
              decoration: InputDecoration(
                labelText: 'e.g. plumbing, wiring, washing machine',
                hintText: '${selectedCategory['slug']}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
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
                    'e.g I install & repair washing machines, dishwashers, TVs. 5 years experience in Kisumu...',
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
                  'Update Public Profile - 24 Categories',
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
              'My Customer Feedbacks',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('fundis')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('reviews')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                if (snap.data!.docs.isEmpty) {
                  return Text(
                    'No feedbacks yet',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.black45,
                    ),
                  );
                }
                return Column(
                  children: snap.data!.docs.map((d) {
                    var r = d.data() as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text(
                        r['clientName'] ?? 'Client',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        r['comment'] ?? '',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      trailing: Text('${r['rating'] ?? 5}★'),
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

  Widget _stat(String v, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            v,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    ),
  );

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
