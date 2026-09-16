import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String userId; // recipient
  final String title;
  final String body;
  final String
  type; // job_confirmed, escrow_held, site_visit, renegotiation_requested, renegotiation_countered, renegotiation_accepted, parts_bought, parts_confirmed, fundi_working, job_completed, payment_released
  final String? jobId;
  final String? jobTitle;
  final bool isRead;
  final Timestamp createdAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.jobId,
    this.jobTitle,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: d['userId'] ?? '',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? 'general',
      jobId: d['jobId'],
      jobTitle: d['jobTitle'],
      isRead: d['isRead'] ?? false,
      createdAt: d['createdAt'] ?? Timestamp.now(),
      data: d['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'isRead': isRead,
      'createdAt': createdAt,
      'data': data,
    };
  }
}
