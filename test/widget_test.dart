import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_sync/models/post_model.dart';

void main() {
  test('PostModel maps collaboration fields safely', () {
    final timestamp = DateTime(2026, 4, 14, 10, 30);
    final expiresAt = timestamp.add(const Duration(hours: 12));
    final post = PostModel(
      id: 'post-1',
      title: 'Need a calculator',
      description: 'Anyone near the library with a spare calculator?',
      postedBy: 'student@campus.edu',
      createdByUid: 'user-1',
      timestamp: timestamp,
      category: 'Study',
      studyResourceType: 'Study Material',
      urgency: 'Soon',
      location: 'Library',
      status: 'Open',
      expiresAt: expiresAt,
      helperIds: const <String>['helper-1'],
      imageUrl: '',
      isAnonymous: false,
      resolvedHelperUid: '',
      resolvedHelperEmail: '',
      resolvedThankYou: '',
      resolvedRating: null,
    );

    final rebuilt = PostModel.fromMap(<String, dynamic>{
      ...post.toMap(),
      'timestamp': Timestamp.fromDate(timestamp),
      'expiresAt': Timestamp.fromDate(expiresAt),
    }, 'post-1');

    expect(rebuilt.id, 'post-1');
    expect(rebuilt.createdByUid, 'user-1');
    expect(rebuilt.category, 'Study');
    expect(rebuilt.studyResourceType, 'Study Material');
    expect(rebuilt.urgency, 'Soon');
    expect(rebuilt.location, 'Library');
    expect(rebuilt.status, 'Open');
    expect(rebuilt.helperCount, 1);
  });
}
