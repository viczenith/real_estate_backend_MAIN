# CLIENT CHAT API SERVICE - FLUTTER INTEGRATION

## API Endpoints

### Base URL
```
https://yourdomain.com/api/
```

---

## 1. Get Chat Messages (Conversation History)

**Endpoint:** `GET /api/client/chat/`

**Description:** Retrieve all messages in the conversation between client and admin support.

**Authentication:** Required (Token/Session)

**Query Parameters:**
- `last_msg_id` (optional): Get only messages after this ID (for polling/real-time updates)
- `page` (optional): Page number for pagination
- `page_size` (optional): Number of messages per page (default: 50, max: 100)

**Response:**
```json
{
    "count": 125,
    "messages": [
        {
            "id": 1,
            "sender_name": "John Doe",
            "sender_role": "client",
            "content": "Hello, I need help with my property",
            "file_url": null,
            "file_type": null,
            "date_sent": "2025-10-14T10:30:00Z",
            "time_ago": "2 hours ago",
            "is_read": true,
            "status": "read",
            "is_sender": true
        },
        {
            "id": 2,
            "sender_name": "Admin Support",
            "sender_role": "admin",
            "content": "Hello! How can I assist you?",
            "file_url": null,
            "file_type": null,
            "date_sent": "2025-10-14T10:35:00Z",
            "time_ago": "2 hours ago",
            "is_read": true,
            "status": "read",
            "is_sender": false
        }
    ]
}
```

---

## 2. Send Message

**Endpoint:** `POST /api/client/chat/send/`

**Description:** Send a new message to admin support.

**Authentication:** Required (Token/Session)

**Content-Type:** `multipart/form-data` (for file uploads) or `application/json`

**Body Parameters:**
- `content` (string, optional if file is provided): Message text
- `file` (file, optional): File attachment
- `message_type` (string, optional): One of 'complaint', 'enquiry', 'compliment' (default: 'enquiry')
- `reply_to` (integer, optional): Message ID to reply to

**Request Example (JSON):**
```json
{
    "content": "I have a question about my payment",
    "message_type": "enquiry"
}
```

**Request Example (with file - multipart/form-data):**
```
content: "Here's the document you requested"
file: [binary file data]
message_type: "enquiry"
```

**Response:**
```json
{
    "success": true,
    "message": {
        "id": 3,
        "sender": {
            "id": 10,
            "email": "client@example.com",
            "full_name": "John Doe",
            "role": "client"
        },
        "recipient": {
            "id": 1,
            "email": "admin@example.com",
            "full_name": "Admin User",
            "role": "admin"
        },
        "message_type": "enquiry",
        "content": "I have a question about my payment",
        "file": null,
        "file_url": null,
        "file_name": null,
        "file_size": null,
        "file_type": null,
        "date_sent": "2025-10-14T12:00:00Z",
        "formatted_date": "Oct 14, 2025 12:00 PM",
        "time_ago": "just now",
        "is_read": false,
        "status": "sent",
        "reply_to": null,
        "is_sender": true
    }
}
```

**Error Response:**
```json
{
    "success": false,
    "errors": {
        "content": ["Please provide either a message or attach a file."]
    }
}
```

---

## 3. Get Message Detail

**Endpoint:** `GET /api/client/chat/<message_id>/`

**Description:** Retrieve details of a specific message.

**Authentication:** Required (Token/Session)

**Response:**
```json
{
    "id": 1,
    "sender": {
        "id": 10,
        "email": "client@example.com",
        "full_name": "John Doe",
        "role": "client"
    },
    "recipient": {
        "id": 1,
        "email": "admin@example.com",
        "full_name": "Admin User",
        "role": "admin"
    },
    "message_type": "enquiry",
    "content": "Hello, I need help",
    "file": "/media/chat_files/document.pdf",
    "file_url": "https://yourdomain.com/media/chat_files/document.pdf",
    "file_name": "document.pdf",
    "file_size": 245678,
    "file_type": "pdf",
    "date_sent": "2025-10-14T10:30:00Z",
    "formatted_date": "Oct 14, 2025 10:30 AM",
    "time_ago": "2 hours ago",
    "is_read": true,
    "status": "read",
    "reply_to": null,
    "is_sender": true
}
```

---

## 4. Delete Message

**Endpoint:** `DELETE /api/client/chat/<message_id>/delete/`

**Description:** Delete a message (only within 30 minutes of sending).

**Authentication:** Required (Token/Session)

**Response (Success):**
```json
{
    "success": true,
    "message": "Message deleted successfully."
}
```

**Error Response (Too Old):**
```json
{
    "success": false,
    "error": "You can only delete messages within 30 minutes of sending."
}
```

**Error Response (Not Found):**
```json
{
    "success": false,
    "error": "Message not found or you do not have permission to delete it."
}
```

---

## 5. Get Unread Count

**Endpoint:** `GET /api/client/chat/unread-count/`

**Description:** Get the count of unread messages from admin and the last message.

**Authentication:** Required (Token/Session)

**Response:**
```json
{
    "unread_count": 5,
    "last_message": {
        "id": 100,
        "sender_name": "Admin Support",
        "sender_role": "admin",
        "content": "Your payment has been processed",
        "file_url": null,
        "file_type": null,
        "date_sent": "2025-10-14T11:00:00Z",
        "time_ago": "1 hour ago",
        "is_read": false,
        "status": "delivered",
        "is_sender": false
    }
}
```

---

## 6. Mark Messages as Read

**Endpoint:** `POST /api/client/chat/mark-read/`

**Description:** Mark specific messages or all messages as read.

**Authentication:** Required (Token/Session)

**Body Parameters:**
- `message_ids` (array of integers, optional): List of message IDs to mark as read
- `mark_all` (boolean, optional): Mark all unread messages as read (default: false)

**Request Example (Mark Specific):**
```json
{
    "message_ids": [1, 2, 3]
}
```

**Request Example (Mark All):**
```json
{
    "mark_all": true
}
```

**Response:**
```json
{
    "success": true,
    "message": "5 message(s) marked as read."
}
```

---

## 7. Poll for New Messages

**Endpoint:** `GET /api/client/chat/poll/`

**Description:** Lightweight endpoint for real-time updates. Get new messages and status updates.

**Authentication:** Required (Token/Session)

**Query Parameters:**
- `last_msg_id` (required): Get only messages after this ID

**Response:**
```json
{
    "new_messages": [
        {
            "id": 101,
            "sender_name": "Admin Support",
            "sender_role": "admin",
            "content": "Thank you for contacting us",
            "file_url": null,
            "file_type": null,
            "date_sent": "2025-10-14T12:05:00Z",
            "time_ago": "just now",
            "is_read": true,
            "status": "read",
            "is_sender": false
        }
    ],
    "count": 1,
    "updated_statuses": [
        {"id": 99, "status": "read"},
        {"id": 100, "status": "read"}
    ]
}
```

---

## Flutter API Service Example

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ClientChatService {
  final String baseUrl;
  final String authToken;

  ClientChatService({
    required this.baseUrl,
    required this.authToken,
  });

  // Common headers
  Map<String, String> get _headers => {
    'Authorization': 'Token $authToken',
    'Content-Type': 'application/json',
  };

  Map<String, String> get _headersMultipart => {
    'Authorization': 'Token $authToken',
  };

  /// Get chat messages (conversation history)
  Future<Map<String, dynamic>> getChatMessages({
    int? lastMsgId,
    int? page,
    int? pageSize,
  }) async {
    final queryParams = <String, String>{};
    if (lastMsgId != null) queryParams['last_msg_id'] = lastMsgId.toString();
    if (page != null) queryParams['page'] = page.toString();
    if (pageSize != null) queryParams['page_size'] = pageSize.toString();

    final uri = Uri.parse('$baseUrl/client/chat/').replace(queryParameters: queryParams);
    
    try {
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  /// Send a text message
  Future<Map<String, dynamic>> sendMessage({
    required String content,
    String messageType = 'enquiry',
    int? replyTo,
  }) async {
    final uri = Uri.parse('$baseUrl/client/chat/send/');
    
    try {
      final body = {
        'content': content,
        'message_type': messageType,
        if (replyTo != null) 'reply_to': replyTo.toString(),
      };

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );
      
      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception('Failed to send message: ${error['errors'] ?? error['error']}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  /// Send a message with file attachment
  Future<Map<String, dynamic>> sendMessageWithFile({
    String? content,
    required File file,
    String messageType = 'enquiry',
    int? replyTo,
  }) async {
    final uri = Uri.parse('$baseUrl/client/chat/send/');
    
    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_headersMultipart);
      
      if (content != null && content.isNotEmpty) {
        request.fields['content'] = content;
      }
      request.fields['message_type'] = messageType;
      if (replyTo != null) {
        request.fields['reply_to'] = replyTo.toString();
      }

      // Add file
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();
      final fileName = file.path.split('/').last;
      
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: fileName,
        contentType: MediaType('application', 'octet-stream'),
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception('Failed to send message: ${error['errors'] ?? error['error']}');
      }
    } catch (e) {
      throw Exception('Error sending message with file: $e');
    }
  }

  /// Get message detail
  Future<Map<String, dynamic>> getMessageDetail(int messageId) async {
    final uri = Uri.parse('$baseUrl/client/chat/$messageId/');
    
    try {
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching message detail: $e');
    }
  }

  /// Delete a message
  Future<Map<String, dynamic>> deleteMessage(int messageId) async {
    final uri = Uri.parse('$baseUrl/client/chat/$messageId/delete/');
    
    try {
      final response = await http.delete(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to delete message');
      }
    } catch (e) {
      throw Exception('Error deleting message: $e');
    }
  }

  /// Get unread count
  Future<Map<String, dynamic>> getUnreadCount() async {
    final uri = Uri.parse('$baseUrl/client/chat/unread-count/');
    
    try {
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load unread count: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unread count: $e');
    }
  }

  /// Mark messages as read
  Future<Map<String, dynamic>> markAsRead({
    List<int>? messageIds,
    bool markAll = false,
  }) async {
    final uri = Uri.parse('$baseUrl/client/chat/mark-read/');
    
    try {
      final body = markAll 
        ? {'mark_all': true}
        : {'message_ids': messageIds};

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to mark as read: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking as read: $e');
    }
  }

  /// Poll for new messages (for real-time updates)
  Future<Map<String, dynamic>> pollNewMessages(int lastMsgId) async {
    final uri = Uri.parse('$baseUrl/client/chat/poll/').replace(
      queryParameters: {'last_msg_id': lastMsgId.toString()}
    );
    
    try {
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to poll messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error polling messages: $e');
    }
  }
}
```

---

## Usage Examples

### 1. Initialize Service
```dart
final chatService = ClientChatService(
  baseUrl: 'https://yourdomain.com/api',
  authToken: 'your-auth-token-here',
);
```

### 2. Load Chat Messages
```dart
try {
  final result = await chatService.getChatMessages(pageSize: 50);
  final messages = result['messages'] as List;
  print('Loaded ${messages.length} messages');
} catch (e) {
  print('Error: $e');
}
```

### 3. Send Text Message
```dart
try {
  final result = await chatService.sendMessage(
    content: 'Hello, I need help with my property',
    messageType: 'enquiry',
  );
  if (result['success'] == true) {
    print('Message sent: ${result['message']}');
  }
} catch (e) {
  print('Error: $e');
}
```

### 4. Send Message with Image
```dart
try {
  final imageFile = File('/path/to/image.jpg');
  final result = await chatService.sendMessageWithFile(
    content: 'Here is the photo you requested',
    file: imageFile,
    messageType: 'enquiry',
  );
  if (result['success'] == true) {
    print('Message with file sent successfully');
  }
} catch (e) {
  print('Error: $e');
}
```

### 5. Get Unread Count (for badge)
```dart
try {
  final result = await chatService.getUnreadCount();
  final unreadCount = result['unread_count'];
  print('You have $unreadCount unread messages');
} catch (e) {
  print('Error: $e');
}
```

### 6. Real-time Updates (Polling)
```dart
int lastMessageId = 0;

// Poll every 2 seconds
Timer.periodic(Duration(seconds: 2), (timer) async {
  try {
    final result = await chatService.pollNewMessages(lastMessageId);
    final newMessages = result['new_messages'] as List;
    
    if (newMessages.isNotEmpty) {
      // Update UI with new messages
      print('Received ${newMessages.length} new messages');
      lastMessageId = newMessages.last['id'];
    }
  } catch (e) {
    print('Polling error: $e');
  }
});
```

### 7. Delete Message
```dart
try {
  final result = await chatService.deleteMessage(messageId);
  if (result['success'] == true) {
    print('Message deleted successfully');
  }
} catch (e) {
  print('Error: $e');
}
```

### 8. Mark All as Read
```dart
try {
  final result = await chatService.markAsRead(markAll: true);
  print(result['message']);
} catch (e) {
  print('Error: $e');
}
```

---

## File Type Detection

The API automatically detects file types and returns them in the `file_type` field:
- `image`: .jpg, .jpeg, .png, .gif, .webp
- `pdf`: .pdf
- `document`: .doc, .docx
- `spreadsheet`: .xls, .xlsx
- `archive`: .zip, .rar, .7z
- `file`: Other file types

---

## Message Status

Messages have three statuses:
- `sent`: Message sent but not delivered
- `delivered`: Message delivered to recipient
- `read`: Message read by recipient

---

## Notes

1. **Authentication**: All endpoints require authentication via Token or Session
2. **File Size Limit**: Check your server configuration for max file upload size
3. **Real-time Updates**: Use the `/poll/` endpoint for lightweight polling every 1-2 seconds
4. **Pagination**: Default page size is 50, maximum is 100
5. **Delete Time Limit**: Messages can only be deleted within 30 minutes of sending
6. **Message Types**: Choose from 'complaint', 'enquiry', or 'compliment'
7. **Auto Mark as Read**: Messages are automatically marked as read when fetched
