import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final WebSocketService _webSocketService = WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    // TODO: Replace with actual WebSocket URL
    _webSocketService.connect('ws://example.com/chat');
    _webSocketService.messages.listen((message) {
      setState(() {
        _messages.add(message);
      });
    });
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      _webSocketService.sendMessage(_messageController.text);
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
