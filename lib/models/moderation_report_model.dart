import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationReportModel {
  const ModerationReportModel({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.reportedByUid,
    required this.reportedByEmail,
    required this.reason,
    required this.timestamp,
  });

  final String id;
  final String postId;
  final String postTitle;
  final String reportedByUid;
  final String reportedByEmail;
  final String reason;
  final DateTime timestamp;

  factory ModerationReportModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    final rawTimestamp = map['timestamp'];
    return ModerationReportModel(
      id: docId,
      postId: (map['postId'] as String? ?? '').trim(),
      postTitle: (map['postTitle'] as String? ?? '').trim(),
      reportedByUid: (map['reportedByUid'] as String? ?? '').trim(),
      reportedByEmail: (map['reportedByEmail'] as String? ?? '').trim(),
      reason: (map['reason'] as String? ?? '').trim(),
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : rawTimestamp is DateTime
          ? rawTimestamp
          : DateTime.now(),
    );
  }
}
