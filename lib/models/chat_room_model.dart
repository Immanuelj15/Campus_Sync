import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  const ChatRoomModel({
    required this.id,
    required this.postId,
    required this.requesterUid,
    required this.requesterEmail,
    required this.helperUid,
    required this.helperEmail,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  final String id;
  final String postId;
  final String requesterUid;
  final String requesterEmail;
  final String helperUid;
  final String helperEmail;
  final String lastMessage;
  final DateTime? lastMessageAt;

  factory ChatRoomModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawLastMessageAt = map['lastMessageAt'];
    return ChatRoomModel(
      id: docId,
      postId: (map['postId'] as String? ?? '').trim(),
      requesterUid: (map['requesterUid'] as String? ?? '').trim(),
      requesterEmail: (map['requesterEmail'] as String? ?? '').trim(),
      helperUid: (map['helperUid'] as String? ?? '').trim(),
      helperEmail: (map['helperEmail'] as String? ?? '').trim(),
      lastMessage: (map['lastMessage'] as String? ?? '').trim(),
      lastMessageAt: rawLastMessageAt is Timestamp
          ? rawLastMessageAt.toDate()
          : rawLastMessageAt is DateTime
          ? rawLastMessageAt
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'postId': postId,
      'requesterUid': requesterUid,
      'requesterEmail': requesterEmail,
      'helperUid': helperUid,
      'helperEmail': helperEmail,
      'participants': <String>[requesterUid, helperUid],
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt == null
          ? null
          : Timestamp.fromDate(lastMessageAt!),
    };
  }

  String otherParticipant(String currentUid) {
    if (requesterUid == currentUid) {
      return helperEmail;
    }
    return requesterEmail;
  }
}
