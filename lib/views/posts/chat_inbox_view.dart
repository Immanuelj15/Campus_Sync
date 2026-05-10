import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:campus_sync/models/chat_room_model.dart';
import 'package:campus_sync/services/db_service.dart';
import 'package:campus_sync/views/posts/post_chat_view.dart';

class ChatInboxView extends StatelessWidget {
  const ChatInboxView({super.key, required this.currentUser});

  final User currentUser;

  @override
  Widget build(BuildContext context) {
    final dbService = DbService();

    return Scaffold(
      appBar: AppBar(title: const Text('Private Chats')),
      body: StreamBuilder<List<ChatRoomModel>>(
        stream: dbService.chatsForUser(currentUser.uid),
        builder: (context, snapshot) {
          final chats = snapshot.data ?? const <ChatRoomModel>[];
          if (chats.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Private chats appear here after a helper joins a request.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUser = chat.otherParticipant(currentUser.uid);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PostChatView(
                        currentUser: currentUser,
                        chatId: chat.id,
                        title: 'Request Chat',
                        otherUserEmail: otherUser,
                      ),
                    ),
                  );
                },
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE0F2FE),
                        child: Text(
                          _initials(otherUser),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF075985),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otherUser,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              chat.lastMessage.isEmpty
                                  ? 'Chat opened. Say hello.'
                                  : chat.lastMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatTimestamp(chat.lastMessageAt),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _initials(String value) {
    final base = value.split('@').first.trim();
    final parts = base.split(RegExp(r'[._\s-]+')).where((part) => part.isNotEmpty);
    final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? 'CS' : letters;
  }

  static String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return 'New';
    }
    final local = timestamp.toLocal();
    final now = DateTime.now();
    if (now.difference(local).inHours < 24) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final suffix = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }
    return '${local.day}/${local.month}';
  }
}
