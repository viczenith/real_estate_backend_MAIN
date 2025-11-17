# CLIENT CHAT API - QUICK REFERENCE

## 📡 Endpoints Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/client/chat/` | Get all chat messages (with pagination) |
| GET | `/api/client/chat/<id>/` | Get single message detail |
| POST | `/api/client/chat/send/` | Send a new message (text or file) |
| DELETE | `/api/client/chat/<id>/delete/` | Delete a message (within 30 min) |
| GET | `/api/client/chat/unread-count/` | Get unread message count + last message |
| POST | `/api/client/chat/mark-read/` | Mark messages as read |
| GET | `/api/client/chat/poll/` | Poll for new messages (real-time) |

---

## 🔑 Key Features

### ✅ What's Implemented
- ✅ Full message history with pagination
- ✅ Send text messages
- ✅ Send file attachments (images, PDFs, docs, etc.)
- ✅ Delete messages (within 30 minutes)
- ✅ Message status tracking (sent/delivered/read)
- ✅ Unread count with badge support
- ✅ Real-time polling for new messages
- ✅ Mark messages as read (individual or all)
- ✅ File type detection (image/pdf/doc/etc.)
- ✅ Reply to messages support
- ✅ Message type categorization (complaint/enquiry/compliment)

### 📝 Message Object Structure
```json
{
  "id": 1,
  "sender_name": "John Doe",
  "sender_role": "client",
  "content": "Message text here",
  "file_url": "https://domain.com/media/file.pdf",
  "file_type": "pdf",
  "date_sent": "2025-10-14T12:00:00Z",
  "time_ago": "2 hours ago",
  "is_read": true,
  "status": "read",
  "is_sender": true
}
```

---

## 🎯 Common Use Cases

### 1. Load Chat on Screen Open
```
GET /api/client/chat/?page_size=50
```

### 2. Send Text Message
```
POST /api/client/chat/send/
Body: { "content": "Hello", "message_type": "enquiry" }
```

### 3. Send Image
```
POST /api/client/chat/send/
Content-Type: multipart/form-data
Body: { "content": "Photo", "file": [binary], "message_type": "enquiry" }
```

### 4. Get Unread Badge Count
```
GET /api/client/chat/unread-count/
Response: { "unread_count": 5, "last_message": {...} }
```

### 5. Real-time Updates (Poll every 2s)
```
GET /api/client/chat/poll/?last_msg_id=100
Response: { "new_messages": [...], "count": 2, "updated_statuses": [...] }
```

### 6. Mark All as Read (when opening chat)
```
POST /api/client/chat/mark-read/
Body: { "mark_all": true }
```

---

## 🚀 Flutter Integration Steps

### Step 1: Add Dependencies
```yaml
dependencies:
  http: ^1.1.0
  http_parser: ^4.0.2
```

### Step 2: Copy Service Class
- Use `ClientChatService` class from documentation
- Initialize with base URL and auth token

### Step 3: Implement in Your Chat Screen
```dart
// Load messages
final result = await chatService.getChatMessages();
setState(() {
  messages = result['messages'];
});

// Send message
await chatService.sendMessage(content: textController.text);

// Start polling
Timer.periodic(Duration(seconds: 2), (timer) async {
  final updates = await chatService.pollNewMessages(lastMsgId);
  // Update UI with new messages
});
```

---

## ⚙️ Configuration Notes

### Authentication
All endpoints require Token authentication:
```
Authorization: Token your-token-here
```

### Content Types
- JSON: `Content-Type: application/json`
- File Upload: `Content-Type: multipart/form-data`

### File Support
Supported file types:
- Images: jpg, jpeg, png, gif, webp
- Documents: pdf, doc, docx, xls, xlsx
- Archives: zip, rar, 7z
- Others: txt, mp3, mp4, etc.

### Pagination
- Default: 50 messages per page
- Maximum: 100 messages per page
- Use `?page=2&page_size=50` for pagination

### Delete Time Limit
- Messages can only be deleted within 30 minutes
- Only sender can delete their own messages

---

## 🎨 UI Tips

### Message Alignment
- `is_sender: true` → Align right (your messages)
- `is_sender: false` → Align left (admin messages)

### Status Icons
- `sent` → Single checkmark ✓
- `delivered` → Double checkmark ✓✓
- `read` → Blue double checkmark ✓✓ (blue)

### File Handling
- Use `file_type` to show appropriate icons
- `file_url` for downloads
- Display image thumbnails for image types
- Show file icon + name for documents

### Real-time Experience
- Poll every 1-2 seconds for active chat
- Poll every 5-10 seconds for background
- Update message status in real-time
- Show "typing..." indicators (client-side)

---

## 📊 Response Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created (message sent) |
| 400 | Bad request (validation error) |
| 401 | Unauthorized (invalid token) |
| 403 | Forbidden (permission denied) |
| 404 | Not found |

---

## 🔧 Testing with Postman/cURL

### Get Messages
```bash
curl -X GET "https://yourdomain.com/api/client/chat/" \
  -H "Authorization: Token your-token-here"
```

### Send Message
```bash
curl -X POST "https://yourdomain.com/api/client/chat/send/" \
  -H "Authorization: Token your-token-here" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message", "message_type": "enquiry"}'
```

### Get Unread Count
```bash
curl -X GET "https://yourdomain.com/api/client/chat/unread-count/" \
  -H "Authorization: Token your-token-here"
```

---

## 🎯 Performance Tips

1. **Pagination**: Always use pagination for large message history
2. **Polling**: Use `last_msg_id` parameter to fetch only new messages
3. **Caching**: Cache messages locally in Flutter
4. **Lazy Loading**: Load older messages on scroll
5. **Compression**: Enable gzip compression on server
6. **Connection**: Use HTTP/2 if available

---

## 🐛 Common Issues & Solutions

### Issue: "Please provide either a message or attach a file"
**Solution**: Ensure either `content` or `file` is provided

### Issue: "You can only delete messages within 30 minutes"
**Solution**: Check message timestamp before allowing delete

### Issue: 401 Unauthorized
**Solution**: Check token validity and format

### Issue: File upload fails
**Solution**: Check `Content-Type: multipart/form-data` and file size limits

### Issue: Messages not updating in real-time
**Solution**: Implement polling with `/poll/` endpoint

---

## 📞 Support

For issues or questions, contact the backend development team.

**API Version:** 1.0  
**Last Updated:** October 14, 2025
