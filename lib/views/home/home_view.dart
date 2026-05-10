import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:campus_sync/models/app_notification_model.dart';
import 'package:campus_sync/models/post_model.dart';
import 'package:campus_sync/services/auth_service.dart';
import 'package:campus_sync/services/db_service.dart';
import 'package:campus_sync/services/notification_service.dart';
import 'package:campus_sync/views/home/activity_view.dart';
import 'package:campus_sync/views/home/moderation_view.dart';
import 'package:campus_sync/views/posts/chat_inbox_view.dart';
import 'package:campus_sync/views/posts/create_post_view.dart';
import 'package:campus_sync/views/posts/post_detail_view.dart';

enum FeedSortOption { newest, urgent, nearestExpiry, mostHelpers }

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final AuthService _authService = AuthService();
  final DbService _dbService = DbService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  bool _showSavedOnly = false;
  bool _openOnly = false;
  FeedSortOption _sortOption = FeedSortOption.newest;

  User? get _currentUser => _authService.currentUser;

  @override
  void initState() {
    super.initState();
    final user = _currentUser;
    if (user != null) {
      _dbService.ensureUserProfile(user: user);
      NotificationService().syncTokenForCurrentUser();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Set<String>>(
          stream: _dbService.blockedUserIds(user.uid),
          builder: (context, blockedSnapshot) {
            final blockedUserIds = blockedSnapshot.data ?? <String>{};

            return StreamBuilder<Set<String>>(
              stream: _dbService.savedPostIds(user.uid),
              builder: (context, savedSnapshot) {
                final savedPostIds = savedSnapshot.data ?? <String>{};

                return StreamBuilder<List<PostModel>>(
                  stream: _dbService.posts,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _InfoState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Unable to load requests',
                        subtitle:
                            'Please check your Firebase connection and try again.',
                        action: FilledButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allPosts = snapshot.data ?? const <PostModel>[];
                    final visiblePosts = allPosts
                        .where(
                          (post) =>
                              !post.isExpired &&
                              !blockedUserIds.contains(post.createdByUid),
                        )
                        .toList();
                    final categories = _buildCategories(visiblePosts);
                    final filteredPosts = _sortPosts(
                      _filterPosts(visiblePosts, savedPostIds),
                    );

                    return RefreshIndicator(
                      color: theme.colorScheme.primary,
                      onRefresh: () async {
                        await Future<void>.delayed(
                          const Duration(milliseconds: 700),
                        );
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _TopBar(
                                    userEmail: user.email ?? '',
                                    onLogout: _authService.signOut,
                                    notificationsButton: _NotificationsButton(
                                      userId: user.uid,
                                      dbService: _dbService,
                                    ),
                                    onOpenChats: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ChatInboxView(currentUser: user),
                                        ),
                                      );
                                    },
                                    onOpenActivity: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ActivityView(currentUser: user),
                                        ),
                                      );
                                    },
                                    onOpenModeration: _isAdmin(user.email)
                                        ? () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const ModerationView(),
                                              ),
                                            );
                                          }
                                        : null,
                                  ),
                                  const SizedBox(height: 18),
                                  _CampusPulseCard(
                                    posts: visiblePosts,
                                    savedCount: savedPostIds.length,
                                  ),
                                  const SizedBox(height: 14),
                                  _CampusZoneBoard(posts: visiblePosts),
                                  const SizedBox(height: 18),
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search requests, people, locations, or keywords',
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                      ),
                                      suffixIcon: _searchController.text.isEmpty
                                          ? const Icon(Icons.tune_rounded)
                                          : IconButton(
                                              onPressed: () {
                                                _searchController.clear();
                                                setState(() {});
                                              },
                                              icon: const Icon(
                                                Icons.close_rounded,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('All Requests'),
                                        selected: !_showSavedOnly,
                                        onSelected: (_) {
                                          setState(
                                            () => _showSavedOnly = false,
                                          );
                                        },
                                      ),
                                      ChoiceChip(
                                        label: const Text('Saved'),
                                        selected: _showSavedOnly,
                                        onSelected: (_) {
                                          setState(() => _showSavedOnly = true);
                                        },
                                      ),
                                      FilterChip(
                                        label: const Text('Open Only'),
                                        selected: _openOnly,
                                        onSelected: (_) {
                                          setState(
                                            () => _openOnly = !_openOnly,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<FeedSortOption>(
                                        value: _sortOption,
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(
                                            value: FeedSortOption.newest,
                                            child: Text('Sort: Newest'),
                                          ),
                                          DropdownMenuItem(
                                            value: FeedSortOption.urgent,
                                            child: Text('Sort: Urgent'),
                                          ),
                                          DropdownMenuItem(
                                            value: FeedSortOption.nearestExpiry,
                                            child: Text('Sort: Nearest Expiry'),
                                          ),
                                          DropdownMenuItem(
                                            value: FeedSortOption.mostHelpers,
                                            child: Text('Sort: Most Helpers'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() => _sortOption = value);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 40,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: categories.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        final category = categories[index];
                                        return FilterChip(
                                          selected:
                                              category == _selectedCategory,
                                          showCheckmark: false,
                                          label: Text(category),
                                          avatar: Icon(
                                            _iconForCategory(category),
                                            size: 18,
                                          ),
                                          onSelected: (_) {
                                            setState(() {
                                              _selectedCategory = category;
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Text(
                                        _showSavedOnly
                                            ? 'Saved requests'
                                            : 'Live requests',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${filteredPosts.length} visible',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (visiblePosts.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _InfoState(
                                icon: Icons.forum_outlined,
                                title: 'No active requests right now',
                                subtitle:
                                    'Posts expire automatically, so the feed stays fresh.',
                              ),
                            )
                          else if (filteredPosts.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _InfoState(
                                icon: _showSavedOnly
                                    ? Icons.bookmark_border_rounded
                                    : Icons.search_off_rounded,
                                title: _showSavedOnly
                                    ? 'No saved requests yet'
                                    : 'No matches found',
                                subtitle: _showSavedOnly
                                    ? 'Bookmark a request to keep it handy here.'
                                    : 'Try another keyword or switch back to all categories.',
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                110,
                              ),
                              sliver: SliverList.separated(
                                itemCount: filteredPosts.length,
                                itemBuilder: (context, index) => _PostCard(
                                  post: filteredPosts[index],
                                  isSaved: savedPostIds.contains(
                                    filteredPosts[index].id,
                                  ),
                                  onSaveToggle: () => _dbService.toggleSavePost(
                                    uid: user.uid,
                                    post: filteredPosts[index],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => PostDetailView(
                                          post: filteredPosts[index],
                                          currentUser: user,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 14),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CreatePostView()),
          );
        },
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('New Request'),
      ),
    );
  }

  List<String> _buildCategories(List<PostModel> posts) {
    final categories = <String>{'All'};
    for (final post in posts) {
      categories.add(post.category);
    }
    return categories.toList();
  }

  List<PostModel> _filterPosts(
    List<PostModel> posts,
    Set<String> savedPostIds,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    return posts.where((post) {
      final matchesCategory =
          _selectedCategory == 'All' || post.category == _selectedCategory;
      final matchesSaved = !_showSavedOnly || savedPostIds.contains(post.id);
      final matchesOpenOnly = !_openOnly || post.status == 'Open';
      final haystack =
          '${post.title} ${post.description} ${post.postedBy} ${post.location} ${post.category} ${post.studyResourceType} ${post.urgency}'
              .toLowerCase();
      final matchesSearch = query.isEmpty || haystack.contains(query);
      return matchesCategory &&
          matchesSearch &&
          matchesSaved &&
          matchesOpenOnly;
    }).toList();
  }

  List<PostModel> _sortPosts(List<PostModel> posts) {
    final sorted = List<PostModel>.from(posts);
    switch (_sortOption) {
      case FeedSortOption.newest:
        sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return sorted;
      case FeedSortOption.urgent:
        sorted.sort((a, b) {
          final urgencyCompare = _urgencyWeight(
            b.urgency,
          ).compareTo(_urgencyWeight(a.urgency));
          if (urgencyCompare != 0) {
            return urgencyCompare;
          }
          return b.timestamp.compareTo(a.timestamp);
        });
        return sorted;
      case FeedSortOption.nearestExpiry:
        sorted.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
        return sorted;
      case FeedSortOption.mostHelpers:
        sorted.sort((a, b) => b.helperCount.compareTo(a.helperCount));
        return sorted;
    }
  }

  static bool _isAdmin(String? email) {
    final value = email?.toLowerCase() ?? '';
    return value.contains('admin');
  }

  static int _urgencyWeight(String urgency) {
    switch (urgency) {
      case 'Urgent':
        return 3;
      case 'Soon':
        return 2;
      default:
        return 1;
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.userEmail,
    required this.onLogout,
    required this.notificationsButton,
    required this.onOpenChats,
    required this.onOpenActivity,
    this.onOpenModeration,
  });

  final String userEmail;
  final Future<void> Function() onLogout;
  final Widget notificationsButton;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenActivity;
  final VoidCallback? onOpenModeration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campus Sync',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userEmail.isEmpty
                    ? 'Peer support network'
                    : 'Signed in as $userEmail',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _SquareIconButton(
          tooltip: 'Chats',
          icon: Icons.forum_rounded,
          onPressed: onOpenChats,
        ),
        const SizedBox(width: 10),
        _SquareIconButton(
          tooltip: 'My Activity',
          icon: Icons.space_dashboard_rounded,
          onPressed: onOpenActivity,
        ),
        if (onOpenModeration != null) ...[
          const SizedBox(width: 10),
          _SquareIconButton(
            tooltip: 'Moderation',
            icon: Icons.admin_panel_settings_outlined,
            onPressed: onOpenModeration!,
          ),
        ],
        notificationsButton,
        const SizedBox(width: 10),
        _SquareIconButton(
          tooltip: 'Logout',
          icon: Icons.logout_rounded,
          onPressed: () {
            onLogout();
          },
        ),
      ],
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.userId, required this.dbService});

  final String userId;
  final DbService dbService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotificationModel>>(
      stream: dbService.notifications(userId),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotificationModel>[];
        final unreadCount = notifications
            .where((notification) => !notification.isRead)
            .length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await dbService.markNotificationsRead(userId);
                  if (!context.mounted) {
                    return;
                  }
                  showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) =>
                        _NotificationsSheet(notifications: notifications),
                  );
                },
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({required this.notifications});

  final List<AppNotificationModel> notifications;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No notifications yet. You will see comments and help offers here.',
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(notification.message),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CampusPulseCard extends StatelessWidget {
  const _CampusPulseCard({required this.posts, required this.savedCount});

  final List<PostModel> posts;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentCount = posts
        .where((post) => DateTime.now().difference(post.timestamp).inHours < 24)
        .length;
    final categories = posts.map((post) => post.category).toSet().length;
    final openCount = posts.where((post) => post.status == 'Open').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF38BDF8), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Campus Pulse',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Real-time peer help, now collaborative.',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Comments, helpers, statuses, bookmarks, notifications, and expiry now work together in the live campus feed.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PulseMetric(
                  icon: Icons.bolt_rounded,
                  label: 'Today',
                  value: '$recentCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PulseMetric(
                  icon: Icons.flag_rounded,
                  label: 'Open',
                  value: '$openCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PulseMetric(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved',
                  value: '$savedCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PulseMetric(
                  icon: Icons.layers_rounded,
                  label: 'Categories',
                  value: '$categories',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampusZoneBoard extends StatelessWidget {
  const _CampusZoneBoard({required this.posts});

  final List<PostModel> posts;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final post in posts) {
      final key = post.location.isEmpty ? 'Unknown' : post.location;
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topZones = entries.take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campus map snapshot',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'A lightweight zone board showing where requests are most active right now.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: topZones
                .map(
                  (entry) => Container(
                    width: 140,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text('${entry.value} requests'),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isSaved,
    required this.onSaveToggle,
    required this.onTap,
  });

  final PostModel post;
  final bool isSaved;
  final Future<void> Function() onSaveToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgencyColor = _colorForUrgency(post.urgency);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        _initialsFromEmail(post.displayAuthor),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PillLabel(
                              label: post.category,
                              icon: _iconForCategory(post.category),
                              background: const Color(0xFFE0F2FE),
                              foreground: const Color(0xFF075985),
                            ),
                            if (post.studyResourceType.isNotEmpty)
                              _PillLabel(
                                label: post.studyResourceType,
                                icon: Icons.library_books_outlined,
                                background: const Color(0xFFF5F3FF),
                                foreground: const Color(0xFF6D28D9),
                              ),
                            _PillLabel(
                              label: post.urgency,
                              icon: Icons.local_fire_department_rounded,
                              background: urgencyColor.withValues(alpha: 0.14),
                              foreground: urgencyColor,
                            ),
                            _PillLabel(
                              label: post.status,
                              icon: Icons.flag_rounded,
                              background: const Color(0xFFE2E8F0),
                              foreground: const Color(0xFF334155),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          post.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          post.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        if (post.hasImage) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              post.imageUrl,
                              height: 130,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onSaveToggle,
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: post.location,
                  ),
                  if (post.studyResourceType.isNotEmpty)
                    _InfoChip(
                      icon: Icons.library_books_outlined,
                      label: post.studyResourceType,
                    ),
                  _InfoChip(
                    icon: Icons.volunteer_activism_rounded,
                    label: '${post.helperCount} helpers',
                  ),
                  _InfoChip(
                    icon: Icons.schedule_rounded,
                    label: _formatTimestamp(post.timestamp),
                  ),
                  if (post.isAnonymous)
                    const _InfoChip(
                      icon: Icons.visibility_off_outlined,
                      label: 'Anonymous',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initialsFromEmail(String email) {
    final base = email.split('@').first.trim();
    if (base.isEmpty) {
      return 'CS';
    }
    final parts = base
        .split(RegExp(r'[._\s-]+'))
        .where((part) => part.isNotEmpty);
    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? base[0].toUpperCase() : letters;
  }

  static String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month} at $hour:$minute $suffix';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InfoState extends StatelessWidget {
  const _InfoState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDCEEFF), Color(0xFFC7F9E9)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 38, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

Color _colorForUrgency(String urgency) {
  switch (urgency) {
    case 'Urgent':
      return const Color(0xFFDC2626);
    case 'Soon':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF059669);
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Tech':
      return Icons.bolt_rounded;
    case 'Study':
      return Icons.menu_book_rounded;
    case 'Travel':
      return Icons.directions_bus_rounded;
    case 'Food':
      return Icons.lunch_dining_rounded;
    case 'Stay':
      return Icons.meeting_room_rounded;
    default:
      return Icons.hub_rounded;
  }
}
