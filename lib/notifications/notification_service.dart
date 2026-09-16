import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static CollectionReference get _col => _firestore.collection('notifications');

  static Future<void> notifyUser({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    String? jobId,
    String? jobTitle,
    Map<String, dynamic>? extraData,
  }) async {
    if (recipientId.trim().isEmpty) {
      print(
        '⚠️ NOTIFICATION FAILED: recipientId is empty for type $type job $jobId',
      );
      return;
    }
    try {
      // Use Timestamp.now() so it shows immediately, not serverTimestamp which is null at first
      await _col.add({
        'userId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'isRead': false,
        'createdAt': Timestamp.now(),
        'data': extraData ?? {},
        'senderId': FirebaseAuth.instance.currentUser?.uid,
      });
      print('✅ NOTIFICATION SENT to $recipientId: $title');
    } catch (e) {
      print('❌ NOTIFICATION ERROR: $e');
    }
  }

  // Extract IDs correctly from your job structure: customerId + assignedFundi
  static String getClientIdFromJob(Map<String, dynamic> job) {
    return (job['customerId'] ??
            job['clientId'] ??
            job['customer_id'] ??
            job['userId'] ??
            '')
        .toString();
  }

  static String getFundiIdFromJob(Map<String, dynamic> job) {
    return (job['assignedFundi'] ??
            job['fundiId'] ??
            job['assigned_fundi'] ??
            '')
        .toString();
  }

  static Future<void> onJobConfirmed({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String fundiId = getFundiIdFromJob(job);
    await notifyUser(
      recipientId: fundiId,
      title: 'New Confirmed Job',
      body: 'You have a new confirmed job: ${job['title']}',
      type: 'job_confirmed',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onEscrowPaid({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String fundiId = getFundiIdFromJob(job);
    double amount = (job['agreedPrice'] ?? job['budget'] ?? 0).toDouble();
    await notifyUser(
      recipientId: fundiId,
      title: 'Escrow Paid',
      body:
          'Client paid KES ${amount.toInt()} for ${job['title']} - you can start site visit',
      type: 'escrow_held',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onSiteVisitDone({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String clientId = getClientIdFromJob(job);
    await notifyUser(
      recipientId: clientId,
      title: 'Fundi Visited Site',
      body: 'Fundi visited your site for ${job['title']}',
      type: 'site_visit_done',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onClientBoughtParts({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String fundiId = getFundiIdFromJob(job);
    await notifyUser(
      recipientId: fundiId,
      title: 'Client Bought Parts',
      body:
          'Client bought parts for ${job['title']}. Please confirm availability.',
      type: 'parts_bought',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onPartsConfirmed({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String clientId = getClientIdFromJob(job);
    await notifyUser(
      recipientId: clientId,
      title: 'Parts Confirmed',
      body: 'Fundi confirmed parts for ${job['title']}. Work will start now.',
      type: 'parts_confirmed',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onFundiWorking({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String clientId = getClientIdFromJob(job);
    await notifyUser(
      recipientId: clientId,
      title: 'Fundi is Working',
      body: 'Fundi started working on ${job['title']}',
      type: 'fundi_working',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onJobCompleted({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String clientId = getClientIdFromJob(job);
    var amount =
        job['renegotiation']?['newLaborTotal'] ?? job['agreedPrice'] ?? 0;
    await notifyUser(
      recipientId: clientId,
      title: 'Job Completed',
      body:
          'Fundi completed ${job['title']}. Please confirm and release KES $amount',
      type: 'job_completed',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  static Future<void> onPaymentReleased({
    required Map<String, dynamic> job,
    required String jobId,
  }) async {
    String fundiId = getFundiIdFromJob(job);
    var amount = job['agreedPrice'] ?? 0;
    await notifyUser(
      recipientId: fundiId,
      title: 'Payment Released',
      body: 'Client released KES $amount for ${job['title']}',
      type: 'payment_released',
      jobId: jobId,
      jobTitle: job['title'],
    );
  }

  // Test notification
  static Future<void> sendTest(String userId) async {
    await notifyUser(
      recipientId: userId,
      title: 'Test Notification',
      body: 'If you see this, notifications work!',
      type: 'test',
      jobId: 'test123',
      jobTitle: 'Test Job',
    );
  }

  static Stream<QuerySnapshot> getUserNotificationsStream(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static Stream<int> getUnreadCountStream(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({'isRead': true});
  }

  static Future<void> markAllAsRead(String userId) async {
    var q = await _col
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in q.docs) {
      doc.reference.update({'isRead': true});
    }
  }
}
