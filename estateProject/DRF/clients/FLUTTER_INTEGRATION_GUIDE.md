# 🚀 FLUTTER INTEGRATION GUIDE
## Client Chat API Service

---

## 📋 STEP 1: Add Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  http_parser: ^4.0.2
```

Run:
```bash
flutter pub get
```

---

## 📁 STEP 2: Add Service File

1. Create folder: `lib/services/`
2. Copy `FLUTTER_CLIENT_CHAT_SERVICE.dart` to `lib/services/client_chat_service.dart`

Or copy this structure:

```
your_flutter_project/
├── lib/
│   ├── services/
│   │   └── client_chat_service.dart   ← Copy the service file here
│   ├── screens/
│   │   └── chat_screen.dart           ← Create your chat UI
│   └── main.dart
```

---

## 🔧 STEP 3: Initialize Service

In your app (e.g., after login):

```dart
import 'package:your_app/services/client_chat_service.dart';

// Initialize
final chatService = ClientChatService(
  baseUrl: 'https://yourdomain.com/api',  // Your API base URL
  authToken: userToken,                    // Token from login
);

// Make it accessible (e.g., via Provider, GetX, or pass to screens)
```

### Option A: Using Provider

```dart
// 1. Add provider dependency
dependencies:
  provider: ^6.0.0

// 2. Create provider
class ChatServiceProvider extends ChangeNotifier {
  ClientChatService? _service;
  
  void initialize(String baseUrl, String token) {
    _service = ClientChatService(
      baseUrl: baseUrl,
      authToken: token,
    );
    notifyListeners();
  }
  
  ClientChatService? get service => _service;
}

// 3. Provide at app level
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatServiceProvider()),
      ],
      child: MyApp(),
    ),
  );
}

// 4. Use in screens
final chatService = Provider.of<ChatServiceProvider>(context).service!;
```

### Option B: Using GetX

```dart
// 1. Add getx dependency
dependencies:
  get: ^4.6.5

// 2. Create controller
class ChatController extends GetxController {
  late ClientChatService chatService;
  
  void initialize(String baseUrl, String token) {
    chatService = ClientChatService(
      baseUrl: baseUrl,
      authToken: token,
    );
  }
}

// 3. Initialize and use
Get.put(ChatController());
Get.find<ChatController>().initialize(baseUrl, token);

// In screens:
final chatService = Get.find<ChatController>().chatService;
```

---

## 💬 STEP 4: Create Chat Screen

### Basic Chat Screen Structure

```dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/client_chat_service.dart';

class ChatScreen extends StatefulWidget {
  final ClientChatService chatService;
  
  const ChatScreen({Key? key, required this.chatService}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  List<dynamic> _messages = [];
  int _lastMessageId = 0;
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;
  
  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startPolling();
  }
  
  @override
  void dispose() {
    _stopPolling();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Load initial messages
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await widget.chatService.getChatMessages(pageSize: 50);
      setState(() {
        _messages = result['messages'] as List;
        if (_messages.isNotEmpty) {
          _lastMessageId = _messages.last['id'];
        }
        _isLoading = false;
      });
      
      // Mark all as read
      await widget.chatService.markAsRead(markAll: true);
      
      // Scroll to bottom
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load messages: $e');
    }
  }
  
  // Send text message
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    
    try {
      final result = await widget.chatService.sendMessage(
        content: text,
        messageType: 'enquiry',
      );
      
      if (result['success'] == true) {
        setState(() {
          _messages.add(result['message']);
          _lastMessageId = result['message']['id'];
        });
        _textController.clear();
        _scrollToBottom();
      }
    } catch (e) {
      _showError('Failed to send message: $e');
    }
  }
  
  // Send image message
  Future<void> _sendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    try {
      final file = File(image.path);
      final result = await widget.chatService.sendMessageWithFile(
        file: file,
        content: 'Image',
        messageType: 'enquiry',
      );
      
      if (result['success'] == true) {
        setState(() {
          _messages.add(result['message']);
          _lastMessageId = result['message']['id'];
        });
        _scrollToBottom();
      }
    } catch (e) {
      _showError('Failed to send image: $e');
    }
  }
  
  // Delete message
  Future<void> _deleteMessage(int messageId, DateTime sentDate) async {
    if (!widget.chatService.canDeleteMessage(sentDate)) {
      _showError('Can only delete messages within 30 minutes');
      return;
    }
    
    try {
      final result = await widget.chatService.deleteMessage(messageId);
      if (result['success'] == true) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == messageId);
        });
      }
    } catch (e) {
      _showError('Failed to delete message: $e');
    }
  }
  
  // Start polling for new messages
  void _startPolling() {
    _pollTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        final result = await widget.chatService.pollNewMessages(_lastMessageId);
        final newMessages = result['new_messages'] as List;
        
        if (newMessages.isNotEmpty) {
          setState(() {
            _messages.addAll(newMessages);
            _lastMessageId = newMessages.last['id'];
          });
          _scrollToBottom();
        }
      } catch (e) {
        print('Polling error: $e');
      }
    });
  }
  
  void _stopPolling() {
    _pollTimer?.cancel();
  }
  
  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Support'),
        actions: [
          // Unread count badge (optional)
          if (_unreadCount > 0)
            Padding(
              padding: EdgeInsets.all(16),
              child: Badge(
                label: Text('$_unreadCount'),
                child: Icon(Icons.notifications),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          
          // Input area
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black12,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isSender = message['is_sender'] == true;
    final sentDate = DateTime.parse(message['date_sent']);
    
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isSender
            ? () => _showDeleteDialog(message['id'], sentDate)
            : null,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: isSender ? Colors.blue : Colors.grey[300],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File preview if exists
              if (message['file_url'] != null)
                _buildFilePreview(message),
              
              // Message text
              if (message['content'] != null && message['content'].isNotEmpty)
                Text(
                  message['content'],
                  style: TextStyle(
                    color: isSender ? Colors.white : Colors.black87,
                  ),
                ),
              
              SizedBox(height: 4),
              
              // Time and status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message['time_ago'],
                    style: TextStyle(
                      fontSize: 11,
                      color: isSender ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  if (isSender) ...[
                    SizedBox(width: 4),
                    Icon(
                      message['status'] == 'read'
                          ? Icons.done_all
                          : Icons.done,
                      size: 16,
                      color: message['status'] == 'read'
                          ? Colors.lightBlue
                          : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFilePreview(Map<String, dynamic> message) {
    if (message['file_type'] == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          message['file_url'],
          width: 200,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message['file_name'] ?? 'File',
                style: TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }
  
  void _showDeleteDialog(int messageId, DateTime sentDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message'),
        content: Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMessage(messageId, sentDate);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

---

## 🎯 STEP 5: Use the Chat Screen

### Navigate to chat screen:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ChatScreen(
      chatService: chatService, // Pass your initialized service
    ),
  ),
);
```

---

## 🔔 STEP 6: Add Unread Badge (Optional)

### In your main navigation:

```dart
// Fetch unread count periodically
Timer.periodic(Duration(seconds: 10), (timer) async {
  try {
    final result = await chatService.getUnreadCount();
    setState(() {
      _unreadCount = result['unread_count'];
    });
  } catch (e) {
    print('Error fetching unread count: $e');
  }
});

// Show badge
Badge(
  label: Text('$_unreadCount'),
  isLabelVisible: _unreadCount > 0,
  child: Icon(Icons.chat),
)
```

---

## 📱 STEP 7: Test Your Integration

### Test checklist:

- [ ] Load messages on screen open
- [ ] Send text message
- [ ] Send image message
- [ ] Receive new messages (polling)
- [ ] Delete recent message
- [ ] Try to delete old message (should fail)
- [ ] Check unread count
- [ ] Mark messages as read
- [ ] Test offline handling

---

## 🎨 STEP 8: Customize UI (Optional)

The provided chat screen is basic. Customize it:

1. **Colors**: Match your app theme
2. **Bubble Style**: Rounded corners, shadows
3. **Typography**: Font sizes and weights
4. **Animations**: Fade in, slide up
5. **File Handling**: Better preview, download
6. **Emojis**: Add emoji picker
7. **Voice Messages**: Add audio recording

---

## 🚨 Error Handling

### Handle common errors:

```dart
try {
  // API call
} catch (e) {
  if (e.toString().contains('Unauthorized')) {
    // Token expired - redirect to login
    Navigator.pushReplacementNamed(context, '/login');
  } else if (e.toString().contains('network')) {
    // Network error - show retry
    _showRetrySnackbar();
  } else {
    // Other errors
    _showError(e.toString());
  }
}
```

---

## 🔐 Security Best Practices

1. **Store Token Securely**:
   ```dart
   // Use flutter_secure_storage
   dependencies:
     flutter_secure_storage: ^9.0.0
   
   final storage = FlutterSecureStorage();
   await storage.write(key: 'auth_token', value: token);
   String? token = await storage.read(key: 'auth_token');
   ```

2. **Validate Files Before Upload**:
   ```dart
   bool isValidFile(File file) {
     final size = file.lengthSync();
     final maxSize = 10 * 1024 * 1024; // 10 MB
     return size <= maxSize;
   }
   ```

3. **Handle Token Expiry**:
   ```dart
   if (response.statusCode == 401) {
     // Clear token and redirect to login
     await storage.delete(key: 'auth_token');
     Navigator.pushReplacementNamed(context, '/login');
   }
   ```

---

## ⚡ Performance Tips

1. **Pagination**: Load 50 messages initially, more on scroll
2. **Image Caching**: Use `cached_network_image` package
3. **Debouncing**: Debounce polling if user is typing
4. **Background Polling**: Reduce frequency when app is backgrounded
5. **Local Storage**: Cache messages locally with `hive` or `sqflite`

---

## 📚 Additional Packages (Optional)

```yaml
dependencies:
  # Security
  flutter_secure_storage: ^9.0.0
  
  # Image handling
  image_picker: ^1.0.4
  cached_network_image: ^3.3.0
  
  # File handling
  file_picker: ^6.1.1
  path_provider: ^2.1.1
  
  # State management
  provider: ^6.0.0
  # OR
  get: ^4.6.5
  
  # Local storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # Permissions
  permission_handler: ^11.0.1
```

---

## 🎉 You're Ready!

Your Flutter app can now:
- ✅ Send and receive messages
- ✅ Upload files and images
- ✅ Get real-time updates
- ✅ Show unread count
- ✅ Delete messages
- ✅ Mark as read

**Need help?** Check the service file comments for detailed usage examples!

---

## 📞 Support

For API issues: Contact backend team  
For Flutter issues: Check Flutter documentation

**Happy Coding! 🚀**
