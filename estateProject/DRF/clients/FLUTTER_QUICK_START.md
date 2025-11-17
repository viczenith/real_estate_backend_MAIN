# 📱 FLUTTER CHAT API - QUICK START

## 🚀 Copy This File → Your Flutter Project

**File:** `FLUTTER_CLIENT_CHAT_SERVICE.dart`  
**Destination:** `lib/services/client_chat_service.dart`

---

## ⚡ 5-MINUTE SETUP

### 1️⃣ Add Dependencies (pubspec.yaml)
```yaml
dependencies:
  http: ^1.1.0
  http_parser: ^4.0.2
```

### 2️⃣ Initialize Service
```dart
final chatService = ClientChatService(
  baseUrl: 'https://yourdomain.com/api',
  authToken: 'your-token',
);
```

### 3️⃣ Use It!
```dart
// Load messages
final messages = await chatService.getChatMessages();

// Send message
await chatService.sendMessage(content: 'Hello');

// Send image
await chatService.sendMessageWithFile(file: imageFile);

// Poll for updates
Timer.periodic(Duration(seconds: 2), (timer) async {
  final updates = await chatService.pollNewMessages(lastMsgId);
});
```

---

## 📋 ALL AVAILABLE METHODS

| Method | Purpose |
|--------|---------|
| `getChatMessages()` | Load conversation history |
| `getMessageDetail()` | Get single message |
| `sendMessage()` | Send text message |
| `sendMessageWithFile()` | Send with attachment |
| `deleteMessage()` | Delete message |
| `getUnreadCount()` | Get unread badge count |
| `markAsRead()` | Mark messages as read |
| `pollNewMessages()` | Real-time updates |
| `canDeleteMessage()` | Check delete eligibility |
| `getFileTypeIcon()` | Get icon for file type |
| `formatFileSize()` | Format bytes to KB/MB |

---

## 🎯 COMMON TASKS

### Load Messages
```dart
final result = await chatService.getChatMessages(pageSize: 50);
final messages = result['messages'];
```

### Send Text
```dart
final result = await chatService.sendMessage(
  content: 'Hello',
  messageType: 'enquiry',
);
```

### Send File
```dart
final result = await chatService.sendMessageWithFile(
  file: File('/path/to/file.jpg'),
  content: 'Photo',
);
```

### Get Unread Count
```dart
final result = await chatService.getUnreadCount();
final count = result['unread_count'];
```

### Delete Message
```dart
await chatService.deleteMessage(messageId);
```

### Mark All Read
```dart
await chatService.markAsRead(markAll: true);
```

### Poll Updates
```dart
Timer.periodic(Duration(seconds: 2), (timer) async {
  final result = await chatService.pollNewMessages(lastMsgId);
  final newMessages = result['new_messages'];
  // Update UI
});
```

---

## 💡 RESPONSE EXAMPLES

### Message Object
```json
{
  "id": 1,
  "sender_name": "John",
  "content": "Hello",
  "file_url": "https://...",
  "file_type": "image",
  "time_ago": "2 hours ago",
  "is_read": true,
  "status": "read",
  "is_sender": true
}
```

### Unread Count
```json
{
  "unread_count": 5,
  "last_message": {...}
}
```

### Send Response
```json
{
  "success": true,
  "message": {...}
}
```

---

## 🔒 ERROR HANDLING

```dart
try {
  await chatService.sendMessage(content: 'Hi');
} catch (e) {
  if (e.toString().contains('401')) {
    // Token expired → Login
  } else if (e.toString().contains('400')) {
    // Validation error
  } else {
    // Other errors
  }
}
```

---

## 📱 BASIC CHAT SCREEN

```dart
class ChatScreen extends StatefulWidget {
  final ClientChatService chatService;
  ChatScreen({required this.chatService});
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<dynamic> _messages = [];
  int _lastMsgId = 0;
  Timer? _pollTimer;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }
  
  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadMessages() async {
    final result = await widget.chatService.getChatMessages();
    setState(() {
      _messages = result['messages'];
      _lastMsgId = _messages.last['id'];
    });
  }
  
  void _startPolling() {
    _pollTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      final result = await widget.chatService.pollNewMessages(_lastMsgId);
      if (result['new_messages'].isNotEmpty) {
        setState(() {
          _messages.addAll(result['new_messages']);
          _lastMsgId = result['new_messages'].last['id'];
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return ListTile(
            title: Text(msg['content'] ?? ''),
            subtitle: Text(msg['time_ago']),
          );
        },
      ),
    );
  }
}
```

---

## 🎨 MESSAGE BUBBLE

```dart
Widget buildMessageBubble(Map message) {
  final isSender = message['is_sender'];
  return Align(
    alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.all(8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSender ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['content'],
            style: TextStyle(
              color: isSender ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message['time_ago'],
                style: TextStyle(fontSize: 10),
              ),
              if (isSender)
                Icon(
                  message['status'] == 'read' 
                    ? Icons.done_all 
                    : Icons.done,
                  size: 14,
                  color: message['status'] == 'read'
                    ? Colors.blue
                    : Colors.grey,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

---

## ⚡ PERFORMANCE TIPS

1. **Pagination**: Load 50 messages at a time
2. **Polling**: Every 2 seconds when active
3. **Caching**: Store messages locally
4. **Lazy Loading**: Load more on scroll
5. **Image Compression**: Before upload

---

## 🔔 UNREAD BADGE

```dart
// In your tab bar or header
Badge(
  label: Text('$unreadCount'),
  isLabelVisible: unreadCount > 0,
  child: IconButton(
    icon: Icon(Icons.chat),
    onPressed: () => Navigator.push(...),
  ),
)

// Update every 10 seconds
Timer.periodic(Duration(seconds: 10), (timer) async {
  final result = await chatService.getUnreadCount();
  setState(() {
    unreadCount = result['unread_count'];
  });
});
```

---

## 📸 IMAGE PICKER

```yaml
dependencies:
  image_picker: ^1.0.4
```

```dart
final picker = ImagePicker();
final XFile? image = await picker.pickImage(
  source: ImageSource.gallery,
);

if (image != null) {
  final file = File(image.path);
  await chatService.sendMessageWithFile(
    file: file,
    content: 'Photo',
  );
}
```

---

## 🎯 FULL EXAMPLE

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:your_app/services/client_chat_service.dart';

class ChatScreen extends StatefulWidget {
  final ClientChatService chatService;
  ChatScreen({required this.chatService});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  List<dynamic> _messages = [];
  int _lastMsgId = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await widget.chatService.getChatMessages(pageSize: 50);
    setState(() {
      _messages = result['messages'];
      if (_messages.isNotEmpty) _lastMsgId = _messages.last['id'];
    });
    _poll();
  }

  void _poll() {
    _pollTimer = Timer.periodic(Duration(seconds: 2), (t) async {
      final r = await widget.chatService.pollNewMessages(_lastMsgId);
      if (r['new_messages'].isNotEmpty) {
        setState(() {
          _messages.addAll(r['new_messages']);
          _lastMsgId = r['new_messages'].last['id'];
        });
      }
    });
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) return;
    final result = await widget.chatService.sendMessage(
      content: _controller.text,
    );
    if (result['success']) {
      setState(() {
        _messages.add(result['message']);
        _lastMsgId = result['message']['id'];
      });
      _controller.clear();
    }
  }

  Future<void> _sendImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    final result = await widget.chatService.sendMessageWithFile(
      file: File(img.path),
    );
    if (result['success']) {
      setState(() {
        _messages.add(result['message']);
        _lastMsgId = result['message']['id'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat Support')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildBubble(_messages[i]),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map m) {
    final isSender = m['is_sender'];
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.all(8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSender ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          m['content'] ?? '',
          style: TextStyle(
            color: isSender ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
```

---

## ✅ TESTING CHECKLIST

- [ ] Load messages
- [ ] Send text message
- [ ] Send image
- [ ] Delete message
- [ ] Real-time updates
- [ ] Unread count
- [ ] Mark as read
- [ ] Error handling
- [ ] Offline mode

---

## 🎉 YOU'RE READY!

**Files to Copy:**
1. ✅ `FLUTTER_CLIENT_CHAT_SERVICE.dart` → `lib/services/`
2. ✅ Create your chat UI
3. ✅ Test and deploy!

**Documentation:**
- Full API Docs: `CLIENT_CHAT_API_DOCUMENTATION.md`
- Integration Guide: `FLUTTER_INTEGRATION_GUIDE.md`
- This Quick Start: Keep handy!

---

**Happy Coding! 🚀**
