import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:campus_sync/models/comment_model.dart';
import 'package:campus_sync/models/post_model.dart';
import 'package:campus_sync/models/user_profile_model.dart';
import 'package:campus_sync/services/db_service.dart';
import 'package:campus_sync/views/posts/post_detail_view.dart';

class ActivityView extends StatelessWidget {
  const ActivityView({super.key, required this.currentUser});

  final User currentUser;

  @override
  Widget build(BuildContext context) {
    final dbService = DbService();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Activity'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Created'),
              Tab(text: 'Saved'),
              Tab(text: 'Helping'),
              Tab(text: 'Replies'),
            ],
          ),
        ),
        body: Column(
          children: [
            StreamBuilder<UserProfileModel?>(
              stream: dbService.userProfile(currentUser.uid),
              builder: (context, snapshot) {
                return _ProfileSummary(profile: snapshot.data, email: currentUser.email ?? '');
              },
            ),
            Expanded(
              child: TabBarView(
                children: [
                  StreamBuilder<List<PostModel>>(
                    stream: dbService.postsCreatedBy(currentUser.uid),
                    builder: (context, snapshot) => _PostList(
                      emptyTitle: 'No requests created yet.',
                      posts: snapshot.data ?? const <PostModel>[],
                      currentUser: currentUser,
                    ),
                  ),
                  StreamBuilder<Set<String>>(
                    stream: dbService.savedPostIds(currentUser.uid),
                    builder: (context, savedSnapshot) {
                      final savedIds = savedSnapshot.data ?? <String>{};
                      return StreamBuilder<List<PostModel>>(
                        stream: dbService.posts,
                        builder: (context, postSnapshot) {
                          final posts = (postSnapshot.data ?? const <PostModel>[])
                              .where((post) => savedIds.contains(post.id))
                              .toList();
                          return _PostList(
                            emptyTitle: 'No saved requests yet.',
                            posts: posts,
                            currentUser: currentUser,
                          );
                        },
                      );
                    },
                  ),
                  StreamBuilder<List<PostModel>>(
                    stream: dbService.postsHelping(currentUser.uid),
                    builder: (context, snapshot) => _PostList(
                      emptyTitle: 'You have not joined any requests yet.',
                      posts: snapshot.data ?? const <PostModel>[],
                      currentUser: currentUser,
                    ),
                  ),
                  StreamBuilder<List<CommentModel>>(
                    stream: dbService.commentsByUser(currentUser.uid),
                    builder: (context, snapshot) => _CommentList(
                      comments: snapshot.data ?? const <CommentModel>[],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profile, required this.email});

  final UserProfileModel? profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    final badges = profile?.badges ?? const <String>[];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile?.name.isNotEmpty == true ? profile!.name : email,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'Created', value: '${profile?.requestsCount ?? 0}'),
              _MetricChip(label: 'Helping', value: '${profile?.helpOffersCount ?? 0}'),
              _MetricChip(label: 'Chats', value: '${profile?.chatCount ?? 0}'),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges.map((badge) => _BadgeChip(text: badge)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({
    required this.emptyTitle,
    required this.posts,
    required this.currentUser,
  });

  final String emptyTitle;
  final List<PostModel> posts;
  final User currentUser;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(child: Text(emptyTitle));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      itemCount: posts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = posts[index];
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PostDetailView(post: post, currentUser: currentUser),
              ),
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('${post.category} • ${post.status} • ${post.location}'),
                const SizedBox(height: 8),
                Text(post.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({required this.comments});

  final List<CommentModel> comments;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(child: Text('No recent replies yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      itemCount: comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comment.message, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Post ID: ${comment.postId}'),
            ],
          ),
        );
      },
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
    );
  }
}
