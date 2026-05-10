import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderUid,
    required this.senderEmail,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final String chatId;
  final String senderUid;
  final String senderEmail;
  final String message;
  final DateTime timestamp;

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawTimestamp = map['timestamp'];
    return ChatMessageModel(
      id: docId,
      chatId: (map['chatId'] as String? ?? '').trim(),
      senderUid: (map['senderUid'] as String? ?? '').trim(),
      senderEmail: (map['senderEmail'] as String? ?? '').trim(),
      message: (map['message'] as String? ?? '').trim(),
      timestamp: rawTimestamp is Timestamp
          ? rawTimestamp.toDate()
          : rawTimestamp is DateTime
          ? rawTimestamp
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'chatId': chatId,
      'senderUid': senderUid,
      'senderEmail': senderEmail,
      'message': message.trim(),
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
