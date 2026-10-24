import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';

class FundiProfileService {
  static String mapOldToCategoryId(String oldProf) {
    final lower = oldProf.toLowerCase();
    const Map<String, String> keywords = {
      'plumb': 'plumbing_waterworks',
      'electrical': 'electrical',
      'electrics': 'electrical',
      'washing': 'appliance_repair',
      'fridge': 'appliance_repair',
      'appliance': 'appliance_repair',
      'cooker': 'appliance_repair',
      'carpentry': 'carpentry_joinery',
      'carpenter': 'carpentry_joinery',
      'weld': 'welding_fabrication',
      'mechanic': 'automotive',
      'automotive': 'automotive',
      'car': 'automotive',
      'tv': 'electronics_repair',
      'electronics': 'electronics_repair',
      'boda': 'motorcycle_boda',
      'motorcycle': 'motorcycle_boda',
      'tuk': 'motorcycle_boda',
      'masonry': 'masonry_building',
      'building': 'masonry_building',
      'paint': 'painting_decoration',
      'roof': 'roofing_guttering',
      'gutter': 'roofing_guttering',
      'tile': 'tiling_flooring',
      'terrazzo': 'tiling_flooring',
      'hvac': 'hvac',
      'ac': 'hvac',
      'solar': 'solar_renewable',
      'inverter': 'solar_renewable',
      'cctv': 'security_systems',
      'security': 'security_systems',
      'glass': 'glass_aluminum',
      'aluminium': 'glass_aluminum',
      'aluminum': 'glass_aluminum',
      'gypsum': 'gypsum_ceiling',
      'ceiling': 'gypsum_ceiling',
      'waterproof': 'waterproofing',
      'borehole': 'borehole_pump',
      'pump': 'borehole_pump',
      'generator': 'generator_power',
      'garden': 'landscaping_gardening',
      'landscap': 'landscaping_gardening',
      'clean': 'cleaning_laundry',
      'pest': 'pest_control',
      'fumigation': 'pest_control',
      'locksmith': 'locksmith',
      'key': 'locksmith',
    };
    for (final e in keywords.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    return 'plumbing_waterworks';
  }

  static Future<(Map<String, dynamic> fundi, Map<String, dynamic> user)>
  loadDocs() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fundiDoc = await FirebaseFirestore.instance
        .collection('fundis')
        .doc(uid)
        .get();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return (fundiDoc.data() ?? {}, userDoc.data() ?? {});
  }

  static int calcProfilePct(Map combined) {
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
    return pct.clamp(0, 100);
  }

  static Future<String> changePhoto(XFile picked) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseStorage.instance.ref().child('fundis/$uid/profile.jpg');
    await ref.putFile(File(picked.path));
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'photoUrl': url,
    });
    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      'photoUrl': url,
    }, SetOptions(merge: true));
    return url;
  }

  static Future<String> uploadDocFile(
    PlatformFile file,
    String field,
    void Function(double) onProgress,
  ) async {
    if (file.path == null) throw 'No path';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ext = file.extension ?? 'pdf';
    final ref = FirebaseStorage.instance.ref().child(
      'fundi_docs/$uid/${field}_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    final task = ref.putFile(File(file.path!));
    task.snapshotEvents.listen((snap) {
      onProgress(snap.bytesTransferred / snap.totalBytes);
    });
    await task;
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      field: FieldValue.arrayUnion([url]),
    }, SetOptions(merge: true));
    return url;
  }

  static Future<void> saveProfile({
    required String selectedCategoryId,
    required List<String> selectedCategoryIds,
    required List<String> selectedSubcategoryIds,
    required Map category,
    required String keyword,
    required String bio,
    required String exp,
    required Map<String, dynamic>? oldData,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final finalKeyword = keyword.trim().isEmpty
        ? (category['slug'] as String)
        : keyword.trim().toLowerCase();
    final allCatIds = {selectedCategoryId, ...selectedCategoryIds}.toList();

    int maxJobs =
        [
              oldData?['jobsCompleted'],
              oldData?['completedJobs'],
              oldData?['jobsDone'],
            ]
            .where((e) => e != null)
            .map((e) => (e as num).toInt())
            .fold<int>(0, (a, b) => a > b ? a : b);
    int maxRefs =
        [
              oldData?['referralYesCount'],
              oldData?['referralCount'],
              oldData?['referralsCount'],
              oldData?['totalReferrals'],
            ]
            .where((e) => e != null)
            .map((e) => (e as num).toInt())
            .fold<int>(0, (a, b) => a > b ? a : b);

    await FirebaseFirestore.instance.collection('fundis').doc(uid).set({
      'primaryCategoryId': selectedCategoryId,
      'primaryCategoryName': category['name'],
      'primaryCategorySlug': category['slug'],
      'categoryIds': allCatIds,
      'categories': allCatIds,
      'subcategoryIds': selectedSubcategoryIds,
      'profession': category['name'],
      'skill': category['name'],
      'searchKeyword': finalKeyword,
      'otherSkills': selectedCategoryIds.map((id) {
        try {
          return category['name'];
        } catch (_) {
          return id;
        }
      }).toList(),
      'bio': bio.trim(),
      'experienceYears': int.tryParse(exp) ?? exp,
      'experience': exp,
      'available': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'jobsCompleted': maxJobs,
      'completedJobs': maxJobs,
      'referralCount': maxRefs,
      'referralYesCount': maxRefs,
      'fraudCount': oldData?['fraudCount'] ?? 0,
      'averageRating': oldData?['averageRating'] ?? oldData?['rating'] ?? 4.5,
      'ratingCount': oldData?['ratingCount'] ?? oldData?['reviewsCount'] ?? 0,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'profession': category['name'],
      'skill': category['name'],
      'primaryCategoryId': selectedCategoryId,
      'categoryIds': allCatIds,
      'searchKeyword': finalKeyword,
    }, SetOptions(merge: true));
  }
}
