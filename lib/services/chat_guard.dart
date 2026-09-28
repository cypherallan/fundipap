import 'package:cloud_firestore/cloud_firestore.dart';

class ChatGuard {
  static final RegExp phoneRegex = RegExp(
    r'(\+?254[ ]?)?(0?[17]\d{2}[ -]?\d{3}[ -]?\d{3})|(\b0?7\d{8}\b)|(\b0?1\d{8}\b)|(\b\d{3}[-\s]\d{3}[-\s]\d{4}\b)|(\b\d{10}\b)',
    caseSensitive: false,
  );

  static bool containsPhone(String text) {
    // strip spaces for 07xx xxx xxx
    String compact = text.replaceAll(RegExp(r'[\s-]'), '');
    if (phoneRegex.hasMatch(text) || phoneRegex.hasMatch(compact)) return true;
    // words like zero seven one...
    if (text.toLowerCase().contains('zero seven')) return true;
    return false;
  }

  static String maskPhone(String text) {
    return text.replaceAll(phoneRegex, '**** ****');
  }

  static Future<void> flagAttempt({
    required String jobId,
    required String senderId,
    required String text,
    required String senderRole,
  }) async {
    await FirebaseFirestore.instance.collection('flaggedContacts').add({
      'jobId': jobId,
      'senderId': senderId,
      'senderRole': senderRole, // client / fundi
      'rawText': text,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'phone_number_attempt',
    });
    // also mark job for admin review
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'hasFlaggedContact': true,
      'lastFlaggedAt': FieldValue.serverTimestamp(),
    });
  }
}
