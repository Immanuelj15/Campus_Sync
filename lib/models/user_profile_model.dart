import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  const UserProfileModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.department,
    required this.year,
    required this.requestsCount,
    required this.helpOffersCount,
    required this.chatCount,
    required this.badges,
    required this.fcmTokens,
    required this.joinedAt,
  });

  final String uid;
  final String email;
  final String name;
  final String department;
  final String year;
  final int requestsCount;
  final int helpOffersCount;
  final int chatCount;
  final List<String> badges;
  final List<String> fcmTokens;
  final DateTime joinedAt;

  factory UserProfileModel.fromMap(Map<String, dynamic> map, String uid) {
    final rawJoinedAt = map['joinedAt'];
    return UserProfileModel(
      uid: uid,
      email: (map['email'] as String? ?? '').trim(),
      name: (map['name'] as String? ?? '').trim(),
      department: (map['department'] as String? ?? '').trim(),
      year: (map['year'] as String? ?? '').trim(),
      requestsCount: (map['requestsCount'] as num?)?.toInt() ?? 0,
      helpOffersCount: (map['helpOffersCount'] as num?)?.toInt() ?? 0,
      chatCount: (map['chatCount'] as num?)?.toInt() ?? 0,
      badges: ((map['badges'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      fcmTokens: ((map['fcmTokens'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      joinedAt: rawJoinedAt is Timestamp
          ? rawJoinedAt.toDate()
          : rawJoinedAt is DateTime
          ? rawJoinedAt
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'email': email.trim(),
      'name': name.trim(),
      'department': department.trim(),
      'year': year.trim(),
      'requestsCount': requestsCount,
      'helpOffersCount': helpOffersCount,
      'chatCount': chatCount,
      'badges': badges,
      'fcmTokens': fcmTokens,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}
