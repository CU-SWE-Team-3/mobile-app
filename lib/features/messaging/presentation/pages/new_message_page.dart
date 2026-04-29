import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/session_provider.dart';
import '../../domain/entities/participant.dart';
import '../providers/messaging_providers.dart';

class NewMessagePage extends ConsumerStatefulWidget {
  const NewMessagePage({super.key});

  @override
  ConsumerState<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends ConsumerState<NewMessagePage> {
  final _searchController = TextEditingController();
  final _messageController = TextEditingController();

  List<Participant> _suggestions = [];
  List<Participant> _results = [];
  Participant? _selectedUser;
  bool _isSearching = false;
  bool _isSending = false;
  bool _hasSearched = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    final userId = ref.read(sessionUserIdProvider);
    if (userId.isEmpty) return;
    try {
      final following = await ref
          .read(messagingRepositoryProvider)
          .getFollowing(userId);
      if (!mounted) return;
      setState(() {
        _suggestions = following.where((p) => p.id != userId).toList();
      });
    } catch (_) {
      // Silently degrade — suggestions are best-effort
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await ref
          .read(messagingRepositoryProvider)
          .searchUsers(query.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasSearched = true;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _selectUser(Participant user) {
    setState(() {
      _selectedUser = user;
      _results = [];
      _hasSearched = false;
    });
    _searchController.clear();
  }

  Future<void> _sendFirstMessage() async {
    final user = _selectedUser;
    final text = _messageController.text.trim();
    if (user == null || text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final message = await ref
          .read(messagingRepositoryProvider)
          .sendMessage(receiverId: user.id, content: text);

      ref.invalidate(conversationsProvider);

      if (!mounted) return;
      // Replace the new-message screen with the chat room so Back goes to inbox
      context.pushReplacement('/messages/chat/${message.conversationId}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('chat_back_button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New Message',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _RecipientField(
            controller: _searchController,
            selectedUser: _selectedUser,
            isSearching: _isSearching,
            onChanged: _onSearchChanged,
            onClearSelected: () => setState(() => _selectedUser = null),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          if (_selectedUser == null) ...[
            Expanded(
              child: _SearchResults(
                suggestions: _suggestions,
                results: _results,
                hasSearched: _hasSearched,
                onSelect: _selectUser,
              ),
            ),
          ] else ...[
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            _ComposeBar(
              controller: _messageController,
              isSending: _isSending,
              onSend: _sendFirstMessage,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecipientField extends StatelessWidget {
  final TextEditingController controller;
  final Participant? selectedUser;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSelected;

  const _RecipientField({
    required this.controller,
    required this.selectedUser,
    required this.isSearching,
    required this.onChanged,
    required this.onClearSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text(
            'To:',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(width: 10),
          if (selectedUser != null) ...[
            _SelectedChip(
              user: selectedUser!,
              onRemove: onClearSelected,
            ),
          ] else ...[
            Expanded(
              child: TextField(
                key: const ValueKey('messaging_recipient_search_field'),
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search people...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: onChanged,
              ),
            ),
            if (isSearching)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF5500),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final Participant user;
  final VoidCallback onRemove;

  const _SelectedChip({required this.user, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5500).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF5500).withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            user.displayName,
            style: const TextStyle(
              color: Color(0xFFFF5500),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFFFF5500)),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<Participant> suggestions;
  final List<Participant> results;
  final bool hasSearched;
  final ValueChanged<Participant> onSelect;

  const _SearchResults({
    required this.suggestions,
    required this.results,
    required this.hasSearched,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasSearched) {
      if (suggestions.isEmpty) {
        return const Center(
          child: Text(
            'Search for someone to message',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        );
      }
      return ListView.builder(
        itemCount: suggestions.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Suggested',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            );
          }
          return _UserTile(user: suggestions[i - 1], onTap: onSelect);
        },
      );
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) => _UserTile(user: results[i], onTap: onSelect),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Participant user;
  final ValueChanged<Participant> onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';
    final hasAvatar = user.avatarUrl != null &&
        user.avatarUrl!.isNotEmpty &&
        !user.avatarUrl!.contains('default-avatar');

    return InkWell(
      onTap: () => onTap(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF2A2A2A),
              backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _ComposeBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('message_input_field'),
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            isSending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF5500),
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey('message_send_button'),
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded),
                    color: const Color(0xFFFF5500),
                    iconSize: 26,
                  ),
          ],
        ),
      ),
    );
  }
}
