# 🏗️ CLIENT CHAT API ARCHITECTURE

## 📊 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       FLUTTER MOBILE APP                         │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              ClientChatService Class                      │   │
│  │  • getChatMessages()                                      │   │
│  │  • sendMessage()                                          │   │
│  │  • sendMessageWithFile()                                  │   │
│  │  • deleteMessage()                                        │   │
│  │  • getUnreadCount()                                       │   │
│  │  • markAsRead()                                           │   │
│  │  • pollNewMessages()                                      │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTP/HTTPS (Token Auth)
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DJANGO REST API                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  DRF/urls.py (Routes)                     │   │
│  │  /api/client/chat/                    → ChatListAPIView  │   │
│  │  /api/client/chat/<id>/               → ChatDetailAPIView│   │
│  │  /api/client/chat/send/               → ChatSendAPIView  │   │
│  │  /api/client/chat/<id>/delete/        → ChatDeleteAPIView│   │
│  │  /api/client/chat/unread-count/       → UnreadCountView  │   │
│  │  /api/client/chat/mark-read/          → MarkReadAPIView  │   │
│  │  /api/client/chat/poll/               → PollAPIView      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                             │                                     │
│                             ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         client_chat_views.py (Business Logic)            │   │
│  │  • ClientChatListAPIView                                 │   │
│  │  • ClientChatDetailAPIView                               │   │
│  │  • ClientChatSendAPIView                                 │   │
│  │  • ClientChatDeleteAPIView                               │   │
│  │  • ClientChatUnreadCountAPIView                          │   │
│  │  • ClientChatMarkAsReadAPIView                           │   │
│  │  • ClientChatPollAPIView                                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                             │                                     │
│                             ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │       chat_serializers.py (Data Transformation)          │   │
│  │  • MessageSenderSerializer                               │   │
│  │  • MessageSerializer (Full)                              │   │
│  │  • MessageCreateSerializer                               │   │
│  │  • MessageListSerializer (Lightweight)                   │   │
│  │  • ChatUnreadCountSerializer                             │   │
│  └──────────────────────────────────────────────────────────┘   │
│                             │                                     │
│                             ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │          estateApp/models.py (Data Models)               │   │
│  │  • Message Model                                         │   │
│  │    - sender (ForeignKey → CustomUser)                    │   │
│  │    - recipient (ForeignKey → CustomUser)                 │   │
│  │    - content (TextField)                                 │   │
│  │    - file (FileField)                                    │   │
│  │    - message_type (CharField)                            │   │
│  │    - status (CharField)                                  │   │
│  │    - is_read (BooleanField)                              │   │
│  │    - date_sent (DateTimeField)                           │   │
│  │    - reply_to (ForeignKey → self)                        │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │   SQLite DB    │
                    │  (Development) │
                    └────────────────┘
```

---

## 🔄 Data Flow Diagrams

### 1️⃣ Send Message Flow

```
Flutter App                  Django API                  Database
    │                           │                           │
    │  POST /chat/send/         │                           │
    ├──────────────────────────>│                           │
    │  {content: "Hello"}       │                           │
    │                           │                           │
    │                           │  Validate Request         │
    │                           │  (CreateSerializer)       │
    │                           │                           │
    │                           │  Get Admin User           │
    │                           │                           │
    │                           │  Create Message           │
    │                           ├──────────────────────────>│
    │                           │                           │
    │                           │  Message Saved            │
    │                           │<──────────────────────────┤
    │                           │                           │
    │                           │  Serialize Response       │
    │                           │  (MessageSerializer)      │
    │                           │                           │
    │  Response: {success:true} │                           │
    │<──────────────────────────┤                           │
    │  + Full Message Object    │                           │
    │                           │                           │
    ▼                           ▼                           ▼
```

### 2️⃣ Get Messages Flow

```
Flutter App                  Django API                  Database
    │                           │                           │
    │  GET /chat/?page_size=50  │                           │
    ├──────────────────────────>│                           │
    │                           │                           │
    │                           │  Query Messages           │
    │                           │  (Filter by user)         │
    │                           ├──────────────────────────>│
    │                           │                           │
    │                           │  Return Messages          │
    │                           │<──────────────────────────┤
    │                           │                           │
    │                           │  Mark Admin Msgs as Read  │
    │                           ├──────────────────────────>│
    │                           │                           │
    │                           │  Serialize Messages       │
    │                           │  (MessageListSerializer)  │
    │                           │                           │
    │  Response: {messages:[]} │                           │
    │<──────────────────────────┤                           │
    │                           │                           │
    ▼                           ▼                           ▼
```

### 3️⃣ Real-time Polling Flow

```
Flutter App                  Django API                  Database
    │                           │                           │
    │  Timer (every 2s)         │                           │
    │  ┌──────────────┐         │                           │
    │  │              │         │                           │
    │  │  GET /poll/  │         │                           │
    │  │  ?last_msg_id=100      │                           │
    │  └──────┬───────┘         │                           │
    │         │                 │                           │
    ├─────────┴────────────────>│                           │
    │                           │                           │
    │                           │  Query New Messages       │
    │                           │  WHERE id > 100           │
    │                           ├──────────────────────────>│
    │                           │                           │
    │                           │  New Messages Found       │
    │                           │<──────────────────────────┤
    │                           │                           │
    │                           │  Get Status Updates       │
    │                           ├──────────────────────────>│
    │                           │                           │
    │                           │  Serialize Response       │
    │                           │                           │
    │  {new_messages:[...],    │                           │
    │   updated_statuses:[...]} │                           │
    │<──────────────────────────┤                           │
    │                           │                           │
    │  Update UI                │                           │
    │  lastMsgId = 102          │                           │
    │                           │                           │
    ▼                           ▼                           ▼
```

---

## 📁 File Structure

```
estateProject/
│
├── DRF/
│   ├── urls.py                          # 🔗 API Routes
│   │
│   └── clients/
│       ├── IMPLEMENTATION_SUMMARY.md     # 📄 This file
│       ├── CLIENT_CHAT_API_DOCUMENTATION.md  # 📚 Full docs
│       ├── QUICK_REFERENCE.md           # 📖 Quick guide
│       │
│       ├── serializers/
│       │   └── chat_serializers.py      # 🔄 Data Serializers
│       │       ├── MessageSenderSerializer
│       │       ├── MessageSerializer
│       │       ├── MessageCreateSerializer
│       │       ├── MessageListSerializer
│       │       └── ChatUnreadCountSerializer
│       │
│       └── api_views/
│           └── client_chat_views.py     # 🎯 API Endpoints
│               ├── ClientChatListAPIView
│               ├── ClientChatDetailAPIView
│               ├── ClientChatSendAPIView
│               ├── ClientChatDeleteAPIView
│               ├── ClientChatUnreadCountAPIView
│               ├── ClientChatMarkAsReadAPIView
│               └── ClientChatPollAPIView
│
└── estateApp/
    └── models.py                        # 💾 Database Models
        └── Message                      # Chat message model
```

---

## 🔐 Authentication Flow

```
┌───────────────────────────────────────────────────────┐
│                   Flutter App Login                    │
│  1. User enters credentials                           │
│  2. POST /api/auth/login/                             │
│  3. Receives: { token: "abc123...", user: {...} }    │
└──────────────────┬────────────────────────────────────┘
                   │
                   │ Store token securely
                   │
                   ▼
┌───────────────────────────────────────────────────────┐
│            All Subsequent API Calls                    │
│  Headers: {                                           │
│    "Authorization": "Token abc123..."                │
│  }                                                    │
└───────────────────────────────────────────────────────┘
                   │
                   ▼
┌───────────────────────────────────────────────────────┐
│          Django Token Authentication                   │
│  • TokenAuthentication validates token                │
│  • Retrieves user from token                          │
│  • Sets request.user                                  │
│  • Proceeds to view if valid                          │
│  • Returns 401 if invalid                             │
└───────────────────────────────────────────────────────┘
```

---

## 🎨 Message Status Lifecycle

```
┌────────┐         ┌───────────┐         ┌──────┐
│  SENT  │────────>│ DELIVERED │────────>│ READ │
└────────┘         └───────────┘         └──────┘
    │                    │                    │
    │                    │                    │
    ▼                    ▼                    ▼
Created by          Admin receives      Admin opens
   client              message             chat
```

### Status Details

**SENT** (`status='sent'`)
- Message created in database
- Not yet seen by admin
- Single checkmark ✓

**DELIVERED** (`status='delivered'`)
- Message visible to admin
- Admin online/received
- Double checkmark ✓✓

**READ** (`status='read'`)
- Admin opened chat
- `is_read=True` flag set
- Blue double checkmark ✓✓ (blue)

---

## 📊 Database Schema

### Message Table

```sql
CREATE TABLE Message (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender_id INTEGER NOT NULL,           -- FK to CustomUser
    recipient_id INTEGER,                 -- FK to CustomUser
    message_type VARCHAR(20),             -- 'complaint', 'enquiry', 'compliment'
    content TEXT,                         -- Message text
    file VARCHAR(100),                    -- File path
    date_sent DATETIME NOT NULL,          -- Timestamp
    is_read BOOLEAN DEFAULT FALSE,        -- Read flag
    status VARCHAR(10) DEFAULT 'sent',    -- 'sent', 'delivered', 'read'
    reply_to_id INTEGER,                  -- FK to self (for replies)
    
    FOREIGN KEY (sender_id) REFERENCES CustomUser(id),
    FOREIGN KEY (recipient_id) REFERENCES CustomUser(id),
    FOREIGN KEY (reply_to_id) REFERENCES Message(id)
);
```

### Indexes (Recommended)

```sql
CREATE INDEX idx_message_sender ON Message(sender_id);
CREATE INDEX idx_message_recipient ON Message(recipient_id);
CREATE INDEX idx_message_date_sent ON Message(date_sent);
CREATE INDEX idx_message_is_read ON Message(is_read);
CREATE INDEX idx_message_status ON Message(status);
```

---

## 🔄 API Request/Response Examples

### Example 1: Load Chat History

**Request:**
```http
GET /api/client/chat/?page_size=50 HTTP/1.1
Host: yourdomain.com
Authorization: Token abc123...
```

**Response:**
```json
{
  "count": 125,
  "messages": [
    {
      "id": 1,
      "sender_name": "John Doe",
      "sender_role": "client",
      "content": "Hello",
      "file_url": null,
      "file_type": null,
      "date_sent": "2025-10-14T10:00:00Z",
      "time_ago": "2 hours ago",
      "is_read": true,
      "status": "read",
      "is_sender": true
    }
  ]
}
```

### Example 2: Send Message with Image

**Request:**
```http
POST /api/client/chat/send/ HTTP/1.1
Host: yourdomain.com
Authorization: Token abc123...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="content"

Here's the photo you requested
------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="image.jpg"
Content-Type: image/jpeg

[binary image data]
------WebKitFormBoundary
Content-Disposition: form-data; name="message_type"

enquiry
------WebKitFormBoundary--
```

**Response:**
```json
{
  "success": true,
  "message": {
    "id": 126,
    "sender": {
      "id": 10,
      "email": "client@example.com",
      "full_name": "John Doe",
      "role": "client"
    },
    "content": "Here's the photo you requested",
    "file_url": "https://yourdomain.com/media/chat_files/image.jpg",
    "file_name": "image.jpg",
    "file_size": 245678,
    "file_type": "image",
    "date_sent": "2025-10-14T12:00:00Z",
    "status": "sent",
    "is_sender": true
  }
}
```

---

## 🎯 Performance Considerations

### Optimization Strategies

1. **Pagination**
   - Limit messages per request (50-100)
   - Load older messages on demand
   - Reduces initial load time

2. **Polling Efficiency**
   - Use `last_msg_id` parameter
   - Only fetch new messages
   - Reduces bandwidth usage

3. **Caching**
   - Cache messages locally in Flutter
   - Only sync new/updated messages
   - Faster UI updates

4. **Lazy Loading**
   - Load initial 50 messages
   - Load more on scroll up
   - Better memory management

5. **File Handling**
   - Compress images before upload
   - Use thumbnails for image previews
   - Stream large files

### Database Query Optimization

```python
# Efficient query with select_related
Message.objects.filter(
    Q(sender=user) | Q(recipient=user)
).select_related('sender', 'recipient').order_by('date_sent')

# Instead of individual queries for each message
```

---

## 🔒 Security Features

✅ **Token Authentication** - Secure API access  
✅ **User Ownership Check** - Only delete own messages  
✅ **Time-Limited Delete** - 30-minute window  
✅ **Permission Classes** - IsAuthenticated required  
✅ **Input Validation** - Serializer validation  
✅ **File Type Validation** - Server-side checks  
✅ **XSS Protection** - Django's built-in sanitization  
✅ **CSRF Protection** - Token-based auth exempt  

---

## 📱 Flutter UI Components Needed

### 1. Chat Screen
- Message list view (scrollable)
- Input field with send button
- File attachment button
- Loading indicators
- Empty state

### 2. Message Bubble
- Left/right alignment based on sender
- Status indicators (✓ ✓✓)
- Timestamp
- File attachments display
- Reply preview

### 3. File Preview
- Image thumbnails
- Document icons
- File size display
- Download button

### 4. Header Badge
- Unread count badge
- Auto-update on new messages

---

## 🎉 Implementation Complete!

Your Client Chat API is production-ready with:

✅ 7 REST API endpoints  
✅ Full CRUD operations  
✅ Real-time polling  
✅ File attachments  
✅ Message status tracking  
✅ Unread count badge  
✅ Complete Flutter service  
✅ Comprehensive documentation  

**Ready for Flutter integration!** 🚀
