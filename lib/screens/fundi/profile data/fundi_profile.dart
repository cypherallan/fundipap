import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import '../../../data/job_taxonomy.dart';
import 'fundi_profile_service.dart';
import '../../fundi/profile data/profile_header.dart';
import '../../fundi/profile data/profile_form.dart';
import '../../fundi/profile data/profile_uploads.dart';

class FundiProfile extends StatefulWidget {
  const FundiProfile({super.key});
  @override
  State<FundiProfile> createState() => _FundiProfileState();
}

class _FundiProfileState extends State<FundiProfile> {
  final _bioCtrl = TextEditingController();
  final _keywordCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  Map<String, dynamic>? data;
  Map<String, dynamic>? userData;
  bool loading = true, uploadingPhoto = false, _uploading = false;
  double _uploadProgress = 0;
  String _uploadingField = '';
  String selectedCategoryId = 'plumbing_waterworks';
  List<String> selectedCategoryIds = [], selectedSubcategoryIds = [];
  int profilePct = 0;

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

  Future<void> _load() async {
    final (fundi, user) = await FundiProfileService.loadDocs();
    data = fundi;
    userData = user;
    var combined = {...user, ...fundi};
    _bioCtrl.text = combined['bio'] ?? '';
    _expCtrl.text =
        (combined['experienceYears'] ?? combined['experience'] ?? '')
            .toString();
    String oldProf =
        combined['profession'] ??
        combined['skill'] ??
        combined['primaryCategoryName'] ??
        'Plumbing';
    selectedCategoryId =
        combined['primaryCategoryId'] ??
        FundiProfileService.mapOldToCategoryId(oldProf);
    List<String> catIds = List<String>.from(
      combined['categoryIds'] ?? combined['categories'] ?? [],
    );
    if (catIds.isEmpty && combined['otherSkills'] != null) {
      for (var s in List<String>.from(combined['otherSkills'])) {
        catIds.add(FundiProfileService.mapOldToCategoryId(s));
      }
    }
    selectedCategoryIds = catIds
        .toSet()
        .where((id) => id != selectedCategoryId)
        .toList();
    selectedSubcategoryIds = List<String>.from(
      combined['subcategoryIds'] ?? [],
    );
    _keywordCtrl.text =
        combined['searchKeyword'] ?? selectedCategory['slug'] ?? '';
    profilePct = FundiProfileService.calcProfilePct(combined);
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
      await FundiProfileService.changePhoto(picked);
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
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> _pickAndUpload(String field) async {
    try {
      final List<PlatformFile> picked = await FilePickerPlatform.instance
          .pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
          );
      if (picked.isEmpty) return;
      setState(() => _uploading = true);
      setState(() => _uploadingField = field);
      await FundiProfileService.uploadDocFile(picked.first, field, (p) {
        if (!mounted) return;
        setState(() => _uploadProgress = p);
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$field uploaded ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
      setState(() => _uploadProgress = 0);
      setState(() => _uploadingField = '');
    }
  }

  Future<void> _save() async {
    await FundiProfileService.saveProfile(
      selectedCategoryId: selectedCategoryId,
      selectedCategoryIds: selectedCategoryIds,
      selectedSubcategoryIds: selectedSubcategoryIds,
      category: selectedCategory,
      keyword: _keywordCtrl.text,
      bio: _bioCtrl.text,
      exp: _expCtrl.text,
      oldData: data,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public profile saved ✨'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    var combined = {...?userData, ...?data};
    var jobsDone =
        [
              combined['jobsCompleted'],
              combined['completedJobs'],
              combined['jobsDone'],
            ]
            .where((e) => e != null)
            .map((e) => (e as num).toInt())
            .fold<int>(0, (a, b) => a > b ? a : b);
    var rating = (combined['averageRating'] ?? combined['rating'] ?? 4.5)
        .toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(
              combined: combined,
              profilePct: profilePct,
              uploadingPhoto: uploadingPhoto,
              onChangePhoto: _changePhoto,
              jobsDone: jobsDone,
              rating: rating,
              ratingCount: combined['ratingCount'] ?? 0,
              fraud: combined['fraudCount'] ?? 0,
            ),
            ProfileForm(
              selectedCategoryId: selectedCategoryId,
              selectedCategoryIds: selectedCategoryIds,
              selectedSubcategoryIds: selectedSubcategoryIds,
              selectedCategory: selectedCategory,
              subcategories: subcategories,
              bioCtrl: _bioCtrl,
              keywordCtrl: _keywordCtrl,
              expCtrl: _expCtrl,
              onCategoryChanged: (v) => setState(() {
                selectedCategoryId = v!;
                selectedSubcategoryIds = [];
              }),
              onSubToggle: (id, sel) => setState(
                () => sel
                    ? selectedSubcategoryIds.add(id)
                    : selectedSubcategoryIds.remove(id),
              ),
              onOtherToggle: (id, sel) => setState(
                () => sel
                    ? selectedCategoryIds.add(id)
                    : selectedCategoryIds.remove(id),
              ),
              onSave: _save,
            ),
            ProfileUploads(
              data: data,
              uploading: _uploading,
              uploadProgress: _uploadProgress,
              uploadingField: _uploadingField,
              onPick: _pickAndUpload,
              onDelete: (f, u) async => await FirebaseFirestore.instance
                  .collection('fundis')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .update({
                    f: FieldValue.arrayRemove([u]),
                  }),
              onLoad: _load,
            ),
          ],
        ),
      ),
    );
  }
}
