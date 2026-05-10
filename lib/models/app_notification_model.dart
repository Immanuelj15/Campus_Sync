import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.postId,
    required this.timestamp,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final String postId;
  final DateTime timestamp;
  final bool isRead;

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawTimestamp = map['timestamp'];
    return AppNotificationModel(
      id: docId,
      title: (map['title'] as String? ?? '').trim(),
      message: (map['message'] as String? ?? '').trim(),
      type: (map['type'] as String? ?? '').trim(),
      postId: (map['postId'] as String? ?? '').trim(),
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : rawTimestamp is DateTime
          ? rawTimestamp
          : DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}
