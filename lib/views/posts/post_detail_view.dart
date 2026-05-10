import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:campus_sync/models/comment_model.dart';
import 'package:campus_sync/models/post_model.dart';
import 'package:campus_sync/models/user_profile_model.dart';
import 'package:campus_sync/services/db_service.dart';
import 'package:campus_sync/views/posts/create_post_view.dart';
import 'package:campus_sync/views/posts/post_chat_view.dart';

class PostDetailView extends StatefulWidget {
  const PostDetailView({
    super.key,
    required this.post,
    required this.currentUser,
  });

  final PostModel post;
  final User currentUser;

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  final DbService _dbService = DbService();
  final TextEditingController _commentController = TextEditingController();

  bool _isSendingComment = false;
  bool _isBusy = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment(PostModel post) async {
    final message = _commentController.text.trim();
    if (message.isEmpty) {
      return;
    }

    setState(() => _isSendingComment = true);
    try {
      await _dbService.addComment(
        post: post,
        comment: CommentModel(
          id: '',
          postId: post.id,
          message: message,
          createdByUid: widget.currentUser.uid,
          createdByEmail: widget.currentUser.email ?? '',
          timestamp: DateTime.now(),
        ),
      );
      _commentController.clear();
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  Future<void> _startHelping(PostModel post) async {
    if (post.helperIds.contains(widget.currentUser.uid)) {
      await _openChatForHelper(post);
      return;
    }

    setState(() => _isBusy = true);
    try {
      await _dbService.toggleHelp(post: post, user: widget.currentUser);
      await _openChatForHelper(post);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _openChatForHelper(PostModel post) async {
    final chatId = await _dbService.createOrGetChat(
      post: post,
      helper: widget.currentUser,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostChatView(
          currentUser: widget.currentUser,
          chatId: chatId,
          title: post.title,
          otherUserEmail: post.postedBy,
        ),
      ),
    );
  }

  Future<void> _openChatWithHelper(PostModel post, UserProfileModel? helper) async {
    if (helper == null) {
      return;
    }
    final chatId = await _dbService.createOrGetChatForParticipants(
      post: post,
      helperUid: helper.uid,
      helperEmail: helper.email,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostChatView(
          currentUser: widget.currentUser,
          chatId: chatId,
          title: post.title,
          otherUserEmail: helper.email,
        ),
      ),
    );
  }

  Future<void> _toggleSave(PostModel post) async {
    await _dbService.toggleSavePost(uid: widget.currentUser.uid, post: post);
  }

  Future<void> _updateStatus(PostModel post, String status) async {
    await _dbService.updatePostStatus(post: post, status: status);
  }

  Future<void> _reportPost(PostModel post) async {
    await _dbService.reportPost(post: post, user: widget.currentUser);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post reported for review.')),
    );
  }

  Future<void> _blockUser(PostModel post) async {
    if (post.createdByUid.isEmpty) {
      return;
    }
    await _dbService.toggleBlockUser(
      uid: widget.currentUser.uid,
      blockedUid: post.createdByUid,
      blockedEmail: post.postedBy,
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete request?'),
        content: const Text('This removes the request and its thread from the live feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _dbService.deletePost(post.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _resolveFlow(PostModel post) async {
    final helperProfiles = await _dbService.userProfilesForIds(post.helperIds);
    if (!mounted) {
      return;
    }
    if (helperProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A helper must join before resolving.')),
      );
      return;
    }

    String selectedUid = helperProfiles.first.uid;
    String selectedEmail = helperProfiles.first.email;
    final thankYouController = TextEditingController();
    double rating = 5;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resolved success flow',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'Who helped?',
                      prefixIcon: Icon(Icons.volunteer_activism_rounded),
                    ),
                    items: helperProfiles
                        .map(
                          (profile) => DropdownMenuItem<String>(
                            value: profile.uid,
                            child: Text(profile.email),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final selectedProfile = helperProfiles.firstWhere(
                        (profile) => profile.uid == value,
                      );
                      setModalState(() {
                        selectedUid = selectedProfile.uid;
                        selectedEmail = selectedProfile.email;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: thankYouController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Thank-you note',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 34),
                        child: Icon(Icons.favorite_outline_rounded),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Rating: ${rating.toInt()} / 5'),
                  Slider(
                    value: rating,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: rating.toInt().toString(),
                    onChanged: (value) => setModalState(() => rating = value),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await _dbService.resolvePost(
                        post: post,
                        helperUid: selectedUid,
                        helperEmail: selectedEmail,
                        thankYou: thankYouController.text,
                        rating: rating.toInt(),
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Mark resolved'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    thankYouController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PostModel?>(
      stream: _dbService.postById(widget.post.id),
      builder: (context, postSnapshot) {
        final livePost = postSnapshot.data ?? widget.post;
        final isOwner = widget.currentUser.uid == livePost.createdByUid;
        final isHelping = livePost.helperIds.contains(widget.currentUser.uid);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Request Room'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CreatePostView(initialPost: livePost),
                        ),
                      );
                    case 'delete':
                      _deletePost(livePost);
                    case 'report':
                      _reportPost(livePost);
                    case 'block':
                      _blockUser(livePost);
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  if (isOwner)
                    const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  if (isOwner)
                    const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                  if (!isOwner)
                    const PopupMenuItem<String>(value: 'report', child: Text('Report')),
                  if (!isOwner && livePost.createdByUid.isNotEmpty)
                    const PopupMenuItem<String>(value: 'block', child: Text('Block user')),
                ],
              ),
            ],
          ),
          body: StreamBuilder<Set<String>>(
            stream: _dbService.savedPostIds(widget.currentUser.uid),
            builder: (context, savedSnapshot) {
              final isSaved = (savedSnapshot.data ?? <String>{}).contains(livePost.id);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(post: livePost),
                    const SizedBox(height: 16),
                    if (livePost.createdByUid.isNotEmpty)
                      StreamBuilder<UserProfileModel?>(
                        stream: _dbService.userProfile(livePost.createdByUid),
                        builder: (context, profileSnapshot) {
                          return _TrustCard(post: livePost, profile: profileSnapshot.data);
                        },
                      ),
                    if (livePost.hasResolutionFeedback) ...[
                      const SizedBox(height: 16),
                      _ResolvedCard(post: livePost),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: isOwner || _isBusy ? null : () => _startHelping(livePost),
                          icon: Icon(
                            isHelping ? Icons.chat_bubble_rounded : Icons.handshake_rounded,
                          ),
                          label: Text(isHelping ? 'Open Chat' : 'I Can Help'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _toggleSave(livePost),
                          icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                          label: Text(isSaved ? 'Saved' : 'Save'),
                        ),
                        if (isOwner)
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: livePost.status,
                              items: postStatuses
                                  .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _updateStatus(livePost, value);
                                }
                              },
                            ),
                          ),
                        if (isOwner)
                          OutlinedButton.icon(
                            onPressed: () => _resolveFlow(livePost),
                            icon: const Icon(Icons.verified_rounded),
                            label: const Text('Resolve'),
                          ),
                      ],
                    ),
                    if (livePost.helperIds.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Helpers in this request',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<UserProfileModel>>(
                        future: _dbService.userProfilesForIds(livePost.helperIds),
                        builder: (context, helpersSnapshot) {
                          final helpers = helpersSnapshot.data ?? const <UserProfileModel>[];
                          if (helpers.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            children: helpers.map((helper) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: const Color(0xFFE0F2FE),
                                      child: Text(_initials(helper.email)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        helper.email,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    if (isOwner)
                                      OutlinedButton.icon(
                                        onPressed: () => _openChatWithHelper(livePost, helper),
                                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                                        label: const Text('Message'),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Comments and replies',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _commentController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Reply to this request',
                              hintText: 'Ask a follow-up or coordinate help here.',
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(bottom: 42),
                                child: Icon(Icons.chat_bubble_outline_rounded),
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _isSendingComment ? null : () => _sendComment(livePost),
                              icon: _isSendingComment
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: const Text('Reply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<CommentModel>>(
                      stream: _dbService.commentsForPost(livePost.id),
                      builder: (context, commentSnapshot) {
                        final comments = commentSnapshot.data ?? const <CommentModel>[];
                        if (comments.isEmpty) {
                          return const _EmptyCard(
                            message: 'No replies yet. Start the conversation and coordinate help here.',
                          );
                        }
                        return Column(
                          children: comments.map((comment) => _CommentTile(comment: comment)).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: post.category),
              if (post.studyResourceType.isNotEmpty)
                _Pill(text: post.studyResourceType),
              _Pill(text: post.urgency),
              _Pill(text: post.status),
              if (post.isAnonymous) const _Pill(text: 'Anonymous'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            post.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            post.description,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), height: 1.45),
          ),
          if (post.hasImage) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(post.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            '${post.location} • ${post.helperCount} helpers • ${post.isExpired ? 'Expired' : 'Active'}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.post, required this.profile});

  final PostModel post;
  final UserProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final badges = profile?.badges ?? const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.isAnonymous ? 'Anonymous Student' : (profile?.email.isNotEmpty == true ? profile!.email : post.postedBy),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('${profile?.department.isNotEmpty == true ? profile!.department : 'Campus member'} • ${profile?.year.isNotEmpty == true ? profile!.year : 'Student'}'),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 14),
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

class _ResolvedCard extends StatelessWidget {
  const _ResolvedCard({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resolved success flow', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (post.resolvedHelperEmail.isNotEmpty) Text('Helper: ${post.resolvedHelperEmail}'),
          if (post.resolvedThankYou.isNotEmpty) Text('Note: ${post.resolvedThankYou}'),
          if (post.resolvedRating != null) Text('Rating: ${post.resolvedRating}/5'),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(comment.createdByEmail, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(comment.message),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(message),
    );
  }
}

String _initials(String email) {
  final base = email.split('@').first;
  return base.isEmpty ? 'CS' : base.substring(0, 1).toUpperCase();
}
