import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PhotoUploader {
  static Future<List<String>> upload(
    List<XFile> files,
    String jobId,
    String folder,
  ) async {
    final urls = <String>[];
    for (final x in files) {
      try {
        final ref = FirebaseStorage.instance.ref().child(
          'jobs/$jobId/$folder/${DateTime.now().millisecondsSinceEpoch}_${x.name}',
        );
        await ref.putFile(File(x.path));
        urls.add(await ref.getDownloadURL());
      } catch (_) {}
    }
    return urls;
  }
}
