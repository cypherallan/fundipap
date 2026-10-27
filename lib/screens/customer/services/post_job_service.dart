import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../../services/location_service.dart';
import '../../../services/pricing_service.dart';

class PostJobService {
  static Future<void> submit({
    required BuildContext context,
    required bool isEdit,
    required String? jobId,
    required String title,
    required String description,
    required String categoryId,
    required String? subcategoryId,
    required String? faultId,
    required String serviceFilter,
    required List<File> photos,
    required List<String> existingPhotos,
    required Map<String, dynamic> selectedCategory,
    required Map<String, dynamic>? selectedSub,
    required List faults,
    required int siteVisitFee,
  }) async {
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill title and description')),
      );
      return;
    }
    if (subcategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select service type')));
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final uData = userDoc.data() ?? {};

      final pos = await LocationService.determinePosition(context);
      if (pos == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not get GPS. Enable location and try again.',
              ),
            ),
          );
        }
        return;
      }

      final accuracy = pos.accuracy;

      final List<String> newUrls = [];
      for (final f in photos) {
        final ref = FirebaseStorage.instance.ref().child(
          'jobs/${uid}_${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last}',
        );
        await ref.putFile(f);
        newUrls.add(await ref.getDownloadURL());
      }
      final allPhotos = [...existingPhotos, ...newUrls];

      final priceInfo = await PricingService.getPriceToShow(
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        faultId: faultId,
      );

      final GeoPoint jobGeo = GeoPoint(pos.latitude, pos.longitude);

      final Map<String, dynamic> jobPayload = {
        'title': title.trim(),
        'description': description.trim(),
        'categoryId': categoryId,
        'categorySlug': selectedCategory['slug'],
        'categoryName': selectedCategory['name'],
        'category': selectedCategory['slug'],
        'subcategoryId': subcategoryId,
        'subcategoryName': selectedSub?['name'] ?? '',
        'serviceFilter': serviceFilter,
        'isInstallation': subcategoryId.toLowerCase().contains('install'),
        'faultId': faultId,
        'faultName': faultId != null
            ? (faults.cast<Map>().firstWhere(
                (ff) => ff['id'] == faultId,
                orElse: () => {"name": faultId},
              )['name'])
            : '',
        'pricingSource': priceInfo['source'],
        'systemPriceMin': priceInfo['min'],
        'systemPriceMax': priceInfo['max'],
        'systemPriceAvg': priceInfo['avg'],
        'marketAvg': priceInfo['avg'],
        'marketCount': priceInfo['count'],
        'siteVisitFee': siteVisitFee,
        'estimatedTotal': (priceInfo['avg'] as int) + siteVisitFee,
        'pricingVersion': PricingService.version,
        'priceDictatedBy': 'fundi_market',
        'requiresSiteVisit': true,
        'budget': priceInfo['avg'],
        'offeredPrice': priceInfo['avg'],
        'budgetMin': priceInfo['min'],
        'budgetMax': priceInfo['max'],
        'photos': allPhotos,
        'images': allPhotos,
        'jobLocation': jobGeo,
        'jobLat': pos.latitude,
        'jobLng': pos.longitude,
        'originalJobLat': pos.latitude,
        'originalJobLng': pos.longitude,
        'originalJobLocation': jobGeo,
        'locationCapturedAt': FieldValue.serverTimestamp(),
        'locationAccuracy': accuracy,
        'customerLat': pos.latitude,
        'customerLng': pos.longitude,
        'clientLat': pos.latitude,
        'clientLng': pos.longitude,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'clientLocation': jobGeo,
        'customerLocation': jobGeo,
        'locationGeoPoint': jobGeo,
        'location':
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
        'locationString':
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isEdit) {
        jobPayload.remove('originalJobLat');
        jobPayload.remove('originalJobLng');
        jobPayload.remove('originalJobLocation');
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .update(jobPayload);
      } else {
        jobPayload.addAll({
          'customerId': uid,
          'clientId': uid,
          'customerName': uData['name'] ?? 'Client',
          'customerUsername': uData['username'] ?? uData['name'] ?? 'Client',
          'clientUsername': uData['username'] ?? uData['name'] ?? 'Client',
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
          'escrowStatus': 'pending',
          'originalCreatedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('jobs').add(jobPayload);
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Job posted: ${selectedCategory['name']} > ${selectedSub?['name']} - ${priceInfo['rangeText']}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      rethrow;
    }
  }
}
