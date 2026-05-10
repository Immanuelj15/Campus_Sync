import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:campus_sync/models/app_notification_model.dart';
import 'package:campus_sync/models/chat_message_model.dart';
import 'package:campus_sync/models/chat_room_model.dart';
import 'package:campus_sync/models/comment_model.dart';
import 'package:campus_sync/models/moderation_report_model.dart';
import 'package:campus_sync/models/post_model.dart';
import 'package:campus_sync/models/user_profile_model.dart';

class DbService {
  DbService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _postsCollection =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _pushQueueCollection =>
      _firestore.collection('push_queue');

  Future<void> createNewPost(PostModel post) async {
    await _postsCollection.add(post.toMap());
    await _usersCollection.doc(post.createdByUid).set(<String, dynamic>{
      'email': post.postedBy,
      'requestsCount': FieldValue.increment(1),
      'badges': _badgeListFromCounts(
        requestsCount: 1,
        helpOffersCount: 0,
        chatCount: 0,
      ),
    }, SetOptions(merge: true));
  }

  Future<void> updatePost(PostModel post) {
    return _postsCollection.doc(post.id).update(post.toMap());
  }

  Future<void> deletePost(String postId) {
    return _postsCollection.doc(postId).delete();
  }

  Stream<List<PostModel>> get posts {
    return _postsCollection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<PostModel>> postsCreatedBy(String uid) {
    return _postsCollection
        .where('createdByUid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<PostModel?> postById(String postId) {
    return _postsCollection.doc(postId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return PostModel.fromMap(data, snapshot.id);
    });
  }

  Stream<List<PostModel>> postsHelping(String uid) {
    return _postsCollection
        .where('helperIds', arrayContains: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PostModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<CommentModel>> commentsForPost(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<CommentModel>> commentsByUser(String uid) {
    return _firestore
        .collectionGroup('comments')
        .where('createdByUid', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> addComment({
    required PostModel post,
    required CommentModel comment,
  }) async {
    await _postsCollection
        .doc(post.id)
        .collection('comments')
        .add(comment.toMap());

    if (post.createdByUid != comment.createdByUid &&
        post.createdByUid.isNotEmpty) {
      await _addNotification(
        userId: post.createdByUid,
        title: 'New reply on your request',
        message: '${comment.createdByEmail} replied to "${post.title}".',
        type: 'comment',
        postId: post.id,
      );
    }
  }

  Future<void> toggleHelp({required PostModel post, required User user}) async {
    final postRef = _postsCollection.doc(post.id);
    final userRef = _usersCollection.doc(user.uid);

    bool wasAdded = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      final latest = PostModel.fromMap(snapshot.data()!, snapshot.id);
      final helperIds = List<String>.from(latest.helperIds);
      final alreadyHelping = helperIds.contains(user.uid);

      if (alreadyHelping) {
        helperIds.remove(user.uid);
      } else {
        helperIds.add(user.uid);
        wasAdded = true;
      }

      final nextStatus = helperIds.isEmpty && latest.status == 'In Progress'
          ? 'Open'
          : !alreadyHelping && latest.status == 'Open'
          ? 'In Progress'
          : latest.status;

      transaction.update(postRef, <String, dynamic>{
        'helperIds': helperIds,
        'status': nextStatus,
      });
    });

    final profile = await userProfileOnce(user.uid);
    final nextHelpCount = (profile?.helpOffersCount ?? 0) + (wasAdded ? 1 : -1);
    final nextBadges = _badgeListFromCounts(
      requestsCount: profile?.requestsCount ?? 0,
      helpOffersCount: nextHelpCount.clamp(0, 1000000),
      chatCount: profile?.chatCount ?? 0,
    );

    await userRef.set(<String, dynamic>{
      'email': user.email ?? '',
      'helpOffersCount': FieldValue.increment(wasAdded ? 1 : -1),
      'badges': nextBadges,
    }, SetOptions(merge: true));

    if (wasAdded &&
        post.createdByUid != user.uid &&
        post.createdByUid.isNotEmpty) {
      await _addNotification(
        userId: post.createdByUid,
        title: 'Someone can help',
        message:
            '${user.email ?? 'A student'} offered help on "${post.title}".',
        type: 'help_offer',
        postId: post.id,
      );
    }
  }

  Future<void> updatePostStatus({
    required PostModel post,
    required String status,
  }) async {
    await _postsCollection.doc(post.id).update(<String, dynamic>{
      'status': status,
    });

    final actorEmail =
        (FirebaseAuth.instance.currentUser?.email ?? '').trim().isNotEmpty
        ? FirebaseAuth.instance.currentUser!.email!.trim()
        : 'Campus Sync';

    for (final helperId in post.helperIds) {
      if (helperId == post.createdByUid) {
        continue;
      }
      await _addNotification(
        userId: helperId,
        title: 'Request status updated',
        message: '$actorEmail changed "${post.title}" to $status.',
        type: 'status_change',
        postId: post.id,
      );
    }
  }

  Future<void> resolvePost({
    required PostModel post,
    required String helperUid,
    required String helperEmail,
    required String thankYou,
    required int rating,
  }) async {
    await _postsCollection.doc(post.id).update(<String, dynamic>{
      'status': 'Resolved',
      'resolvedHelperUid': helperUid,
      'resolvedHelperEmail': helperEmail,
      'resolvedThankYou': thankYou.trim(),
      'resolvedRating': rating,
    });

    if (helperUid.isNotEmpty) {
      await _addNotification(
        userId: helperUid,
        title: 'You were thanked for helping',
        message: 'Your help on "${post.title}" was marked as resolved.',
        type: 'resolved',
        postId: post.id,
      );
    }
  }

  Future<void> clearResolvedFeedback(PostModel post) {
    return _postsCollection.doc(post.id).update(<String, dynamic>{
      'status': 'Open',
      'resolvedHelperUid': '',
      'resolvedHelperEmail': '',
      'resolvedThankYou': '',
      'resolvedRating': null,
    });
  }

  Future<void> toggleSavePost({
    required String uid,
    required PostModel post,
  }) async {
    final ref = _usersCollection
        .doc(uid)
        .collection('saved_posts')
        .doc(post.id);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      await ref.delete();
    } else {
      await ref.set(<String, dynamic>{
        'postId': post.id,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<Set<String>> savedPostIds(String uid) {
    return _usersCollection
        .doc(uid)
        .collection('saved_posts')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<void> upsertUserProfile(UserProfileModel profile) {
    return _usersCollection
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Stream<UserProfileModel?> userProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return UserProfileModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }

  Future<UserProfileModel?> userProfileOnce(String uid) async {
    final snapshot = await _usersCollection.doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return UserProfileModel.fromMap(snapshot.data()!, snapshot.id);
  }

  Future<List<UserProfileModel>> userProfilesForIds(List<String> uids) async {
    final uniqueIds = uids.where((uid) => uid.trim().isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) {
      return const <UserProfileModel>[];
    }

    final snapshots = await Future.wait(
      uniqueIds.map((uid) => _usersCollection.doc(uid).get()),
    );

    return snapshots
        .where((snapshot) => snapshot.exists && snapshot.data() != null)
        .map((snapshot) => UserProfileModel.fromMap(snapshot.data()!, snapshot.id))
        .toList();
  }

  Future<void> ensureUserProfile({
    required User user,
    String? name,
    String? department,
    String? year,
  }) async {
    final ref = _usersCollection.doc(user.uid);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      await ref.set(<String, dynamic>{
        'email': user.email ?? '',
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (department != null && department.trim().isNotEmpty)
          'department': department.trim(),
        if (year != null && year.trim().isNotEmpty) 'year': year.trim(),
      }, SetOptions(merge: true));
      return;
    }

    final fallbackName = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : (user.email ?? 'Student').split('@').first;

    final profile = UserProfileModel(
      uid: user.uid,
      email: user.email ?? '',
      name: fallbackName,
      department: department?.trim() ?? '',
      year: year?.trim() ?? '',
      requestsCount: 0,
      helpOffersCount: 0,
      chatCount: 0,
      badges: const <String>[],
      fcmTokens: const <String>[],
      joinedAt: DateTime.now(),
    );
    await upsertUserProfile(profile);
  }

  Stream<List<AppNotificationModel>> notifications(String uid) {
    return _usersCollection
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotificationModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<Set<String>> blockedUserIds(String uid) {
    return _usersCollection
        .doc(uid)
        .collection('blocked_users')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<void> toggleBlockUser({
    required String uid,
    required String blockedUid,
    required String blockedEmail,
  }) async {
    final ref = _usersCollection
        .doc(uid)
        .collection('blocked_users')
        .doc(blockedUid);
    final snapshot = await ref.get();

    if (snapshot.exists) {
      await ref.delete();
    } else {
      await ref.set(<String, dynamic>{
        'email': blockedEmail,
        'blockedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> reportPost({
    required PostModel post,
    required User user,
    String reason = 'Inappropriate or unsafe content',
  }) {
    return _postsCollection
        .doc(post.id)
        .collection('reports')
        .add(<String, dynamic>{
          'postId': post.id,
          'postTitle': post.title,
          'reportedByUid': user.uid,
          'reportedByEmail': user.email ?? '',
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Stream<List<ModerationReportModel>> reports() {
    return _firestore
        .collectionGroup('reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ModerationReportModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<String> createOrGetChat({
    required PostModel post,
    required User helper,
  }) {
    return createOrGetChatForParticipants(
      post: post,
      helperUid: helper.uid,
      helperEmail: helper.email ?? '',
    );
  }

  Future<String> createOrGetChatForParticipants({
    required PostModel post,
    required String helperUid,
    required String helperEmail,
  }) async {
    final existing = await _chatsCollection
        .where('postId', isEqualTo: post.id)
        .where('helperUid', isEqualTo: helperUid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final doc = await _chatsCollection.add(
      ChatRoomModel(
        id: '',
        postId: post.id,
        requesterUid: post.createdByUid,
        requesterEmail: post.postedBy,
        helperUid: helperUid,
        helperEmail: helperEmail,
        lastMessage: '',
        lastMessageAt: null,
      ).toMap(),
    );

    final requesterProfile = await userProfileOnce(post.createdByUid);
    final helperProfile = await userProfileOnce(helperUid);

    await _usersCollection.doc(post.createdByUid).set(<String, dynamic>{
      'chatCount': FieldValue.increment(1),
      'badges': _badgeListFromCounts(
        requestsCount: requesterProfile?.requestsCount ?? 0,
        helpOffersCount: requesterProfile?.helpOffersCount ?? 0,
        chatCount: (requesterProfile?.chatCount ?? 0) + 1,
      ),
    }, SetOptions(merge: true));
    await _usersCollection.doc(helperUid).set(<String, dynamic>{
      'chatCount': FieldValue.increment(1),
      'badges': _badgeListFromCounts(
        requestsCount: helperProfile?.requestsCount ?? 0,
        helpOffersCount: helperProfile?.helpOffersCount ?? 0,
        chatCount: (helperProfile?.chatCount ?? 0) + 1,
      ),
    }, SetOptions(merge: true));

    if (post.createdByUid.isNotEmpty && post.createdByUid != helperUid) {
      await _addNotification(
        userId: post.createdByUid,
        title: 'Private chat started',
        message:
            '${helperEmail.isEmpty ? 'A helper' : helperEmail} opened a chat for "${post.title}".',
        type: 'chat',
        postId: post.id,
      );
    }

    return doc.id;
  }

  Stream<List<ChatRoomModel>> chatsForUser(String uid) {
    return _chatsCollection
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatRoomModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<ChatRoomModel?> chatRoom(String chatId) {
    return _chatsCollection.doc(chatId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }
      return ChatRoomModel.fromMap(data, snapshot.id);
    });
  }

  Stream<List<ChatMessageModel>> chatMessages(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> sendChatMessage({
    required ChatRoomModel chat,
    required User sender,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }

    await _chatsCollection
        .doc(chat.id)
        .collection('messages')
        .add(
          ChatMessageModel(
            id: '',
            chatId: chat.id,
            senderUid: sender.uid,
            senderEmail: sender.email ?? '',
            message: trimmed,
            timestamp: DateTime.now(),
          ).toMap(),
        );

    await _chatsCollection.doc(chat.id).set(<String, dynamic>{
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final otherUserId = chat.requesterUid == sender.uid
        ? chat.helperUid
        : chat.requesterUid;
    await _addNotification(
      userId: otherUserId,
      title: 'New private message',
      message: '${sender.email ?? 'A student'} sent you a message.',
      type: 'chat_message',
      postId: chat.postId,
    );
  }

  Future<void> saveFcmToken({required String uid, required String token}) {
    return _usersCollection.doc(uid).set(<String, dynamic>{
      'fcmTokens': FieldValue.arrayUnion(<String>[token]),
    }, SetOptions(merge: true));
  }

  Future<void> _addNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    required String postId,
  }) async {
    await _usersCollection
        .doc(userId)
        .collection('notifications')
        .add(<String, dynamic>{
          'title': title,
          'message': message,
          'type': type,
          'postId': postId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await _queuePushNotification(
      userId: userId,
      title: title,
      body: message,
      type: type,
      postId: postId,
    );
  }

  Future<void> _queuePushNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String postId,
  }) async {
    final profile = await userProfileOnce(userId);
    final tokens = profile?.fcmTokens ?? const <String>[];
    if (tokens.isEmpty) {
      return;
    }

    await _pushQueueCollection.add(<String, dynamic>{
      'userId': userId,
      'tokens': tokens,
      'title': title,
      'body': body,
      'type': type,
      'postId': postId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  Future<void> markNotificationsRead(String uid) async {
    final snapshot = await _usersCollection
        .doc(uid)
        .collection('notifications')
        .get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, <String, dynamic>{'isRead': true});
    }
    await batch.commit();
  }

  List<String> _badgeListFromCounts({
    required int requestsCount,
    required int helpOffersCount,
    required int chatCount,
  }) {
    final badges = <String>[];
    if (helpOffersCount >= 1) {
      badges.add('Helpful Human');
    }
    if (helpOffersCount >= 5) {
      badges.add('Quick Responder');
    }
    if (chatCount >= 3) {
      badges.add('Campus Connector');
    }
    if (requestsCount >= 3) {
      badges.add('Active Seeker');
    }
    return badges;
  }
}
