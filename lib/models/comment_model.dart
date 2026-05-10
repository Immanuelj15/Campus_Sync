import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  const CommentModel({
    required this.id,
    required this.postId,
    required this.message,
    required this.createdByUid,
    required this.createdByEmail,
    required this.timestamp,
  });

  final String id;
  final String postId;
  final String message;
  final String createdByUid;
  final String createdByEmail;
  final DateTime timestamp;

  factory CommentModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawTimestamp = map['timestamp'];
    return CommentModel(
      id: docId,
      postId: (map['postId'] as String? ?? '').trim(),
      message: (map['message'] as String? ?? '').trim(),
      createdByUid: (map['createdByUid'] as String? ?? '').trim(),
      createdByEmail: (map['createdByEmail'] as String? ?? '').trim(),
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : rawTimestamp is DateTime
          ? rawTimestamp
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'postId': postId,
      'message': message.trim(),
      'createdByUid': createdByUid,
      'createdByEmail': createdByEmail.trim(),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
