import 'package:flutter/material.dart';

import '../core/supabase.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/services.dart';

/// In-app secure chat (PRD §6) — realtime via Supabase streams.
class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chat = ChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await _chat.send(widget.conversationId, text);
  }

  @override
  Widget build(BuildContext context) {
    final myId = db.auth.currentUser!.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Job chat')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chat.stream(widget.conversationId),
              builder: (context, snap) {
                final msgs = snap.data ?? [];
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m.senderId == myId;
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mine ? WL.green : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: mine
                              ? null
                              : Border.all(color: WL.line),
                        ),
                        child: Text(
                          m.body ?? '',
                          style: TextStyle(
                              color: mine ? Colors.white : WL.ink,
                              fontSize: 14),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                          hintText: 'Type a message…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                        backgroundColor: WL.green),
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
