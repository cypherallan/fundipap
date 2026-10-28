import 'dart:io';
import 'dart:ui';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AnchorVerifier {
  static Future<Map<String, dynamic>> verify({
    required String jobId,
    required String? clientPhotoUrl,
    required String localPath,
    required Rect blurRect,
  }) async {
    if (clientPhotoUrl == null) {
      return {'verified': true, 'reason': 'No anchor photo'};
    }

    final ref = FirebaseStorage.instance.ref().child(
      'jobs/$jobId/verification_temp/${DateTime.now().millisecondsSinceEpoch}_${localPath.split('/').last}',
    );

    await ref.putFile(File(localPath));
    final verifyUrl = await ref.getDownloadURL();

    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('verifyAnchorPhoto')
          .call({
            'jobId': jobId,
            'clientPhotoUrl': clientPhotoUrl,
            'verificationPhotoUrl': verifyUrl,
            'blurRect': {
              'left': blurRect.left,
              'top': blurRect.top,
              'width': blurRect.width,
              'height': blurRect.height,
            },
          });

      final data = Map<String, dynamic>.from(res.data);
      await ref.delete().catchError((_) {});
      return data;
    } catch (e) {
      await ref.delete().catchError((_) {});
      rethrow;
    }
  }
}
