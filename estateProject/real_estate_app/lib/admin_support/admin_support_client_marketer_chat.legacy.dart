import 'dart:async';
.min,
          children: [
            _buildNotificationSettingTile(
              icon: Icons.volume_up_rounded,
              title: 'Sound',
              subtitle: 'Play notification sound',
              value: _notificationService.soundEnabled,
              onChanged: (value) async {
                await _notificationService.updateNotificationSettings(
                    sound: value);
                setState(() {}); // Refresh UI
              },
            ),
            _buildNotificationSettingTile(
              icon: Icons.vibration_rounded,
              title: 'Vibration',
              subtitle: 'Vibrate on new messages',
              value: _notificationService.vibrationEnabled,
              onChanged: (value) async {
                await _notificationService.updateNotificationSettings(
                    vibration: value);
                setState(() {}); // Refresh UI
              },
            ),
            _buildNotificationSettingTile(
              icon: Icons.lightbulb_outline_rounded,
              title: 'LED Light',
              subtitle: 'Flash LED for notifications',
              value: _notificationService.ledEnabled,
              onChanged: (value) async {
                await _notificationService.updateNotificationSettings(
                    led: value);
                setState(() {}); // Refresh UI
              },
            ),
            _buildNotificationSettingTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Popup',
              subtitle: 'Show notifications when app is open',
              value: _notificationService.popupEnabled,
              onChanged: (value) async {
                await _notificationService.updateNotificationSettings(
                    popup: value);
                setState(() {}); // Refresh UI
              },
            ),
            const SizedBox(height: 16),
            // Test notification button
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    // First try simple test notification
                    print('🔔 Testing simple notification...');
                    await _notificationService.showSimpleTestNotification();

                    // Then try the scheduled test notification
                    print('🔔 Testing scheduled notification...');
                    await _notificationService.scheduleTestNotification();
                    _showSuccessMessage('🔔 Test notification sent!');
                  } catch (e) {
                    print('❌ Test notification failed: $e');
                    _showErrorMessage('Test notification failed: $e');
                  }
                },
                icon: Icon(Icons.notifications_active_rounded),
                label: const Text('Test Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(
                color: Color(0xFF128C7E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build notification setting tile
  Widget _buildNotificationSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF128C7E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF128C7E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF303030),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,

  @override
  _AdminSupportClientMarketerChatState createState() =>
      _AdminSupportClientMarketerChatState();
}

class _AdminSupportClientMarketerChatState
    extends State<AdminSupportClientMarketerChat> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollingTimer;
  String? _cachedEndpoint;
  bool _isPolling = false;
  bool _isLoading = false;
  bool _isSending = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _messages = [];
  int _lastMessageId = 0;
  String? _participantAvatar;
  String? _participantInitials;
  String? _participantEmail;
  String? _participantRole;
  String? _currentUserProfileImageUrl;

  ApiService get _apiService => ApiService();
  NotificationService get _notificationService => NotificationService();

  @override
  void initState() {
    super.initState();
    _initializeChatData();
    _startPolling();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeChatData() async {
    try {
      await Future.wait([
        _loadThread(),
        _loadCurrentUserProfile(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize chat. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadThread() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final token = widget.token;

      if (token.isEmpty) {
        setState(() {
          _errorMessage =
              'Authentication token is missing. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final response = await _apiService.fetchSupportChatThread(
        token: widget.token,
        role: widget.role,
        participantId: widget.participantId,
      );

      final participant = response['participant'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final messages = (response['messages'] as List<dynamic>? ?? <dynamic>[])
          .map<Map<String, dynamic>>((dynamic entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

      setState(() {
        _messages = messages;
        _lastMessageId = response['last_message_id'] as int? ?? _lastMessageId;

        _participantAvatar = participant['avatar_url']?.toString();
        _participantInitials = participant['initials']?.toString();
        _participantEmail = participant['email']?.toString();
        _participantRole = participant['role']?.toString();
      });

      _scrollToBottom();
      await _markMessagesAsRead();
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final token = widget.token;

      if (token.isEmpty) return;

      final url = '${_apiService.baseUrl}/client/chat/mark-read/';

      await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'mark_all': true,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Silent fail - marking as read is not critical
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final token = widget.token;

      if (token.isEmpty) return;

      final profileData =
          await _apiService.getClientDetailByToken(token: token);

      setState(() {
        final profileImage = profileData['profile_image']?.toString();
        _currentUserProfileImageUrl =
            (profileImage != null && profileImage.trim().isNotEmpty)
                ? profileImage.trim()
                : '';
      });
    } catch (e) {
      // Silent fail - profile loading is not critical
    }
  }

  void _startPolling() {
    // Production polling optimized for battery and performance
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isPolling && mounted && !_isLoading) {
        _pollForNewMessages();
      }
    });
  }

  // Start aggressive polling for read receipts after sending a message
  void _startAggressiveReadReceiptPolling() {
    // Poll every 200ms for the first 10 seconds after sending a message
    // This ensures immediate blue checkmarks when admin reads the message
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || timer.tick > 50) {
        // Stop after 10 seconds (50 * 200ms)
        timer.cancel();
        return;
      }

      if (!_isPolling) {
        _pollForNewMessages();
      }
    });
  }

  Future<void> _pollForNewMessages() async {
    if (_isPolling || _isLoading) return;

    try {
      _isPolling = true;
      final token = widget.token;

      if (token.isEmpty) return;

      // Use cached endpoint for polling or fallback to default
      final endpoint = _cachedEndpoint ?? '/client/chat/';
      final lastMessageId = _messages.isNotEmpty ? _messages.last['id'] : 0;
      final url =
          '${_apiService.baseUrl}${endpoint}poll/?last_msg_id=$lastMessageId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newMessages = data['new_messages'] as List<dynamic>? ?? [];

        print(
            '📱 Polling response - new messages count: ${newMessages.length}');

        bool hasNewMessages = false;

        if (newMessages.isNotEmpty) {
          print('📱 Processing ${newMessages.length} new messages...');

          // First collect new messages that need notifications
          List<Map<String, dynamic>> messagesForNotification = [];

          setState(() {
            // Add new messages in real-time with proper duplicate checking
            for (var newMsg in newMessages) {
              final newMsgMap =
                  _normalizeIncomingMessage(newMsg as Map<String, dynamic>);

              print('📱 Processing message: ${newMsgMap}');

              // Validate and check for duplicates by ID only (no temp messages)
              if (_isValidBackendMessage(newMsgMap)) {
                final msgId = newMsgMap['id'];
                final exists =
                    _messages.any((existingMsg) => existingMsg['id'] == msgId);

                if (!exists) {
                  print('📱 Adding new message to list - ID: $msgId');
                  _messages.add(newMsgMap);
                  hasNewMessages = true;

                  // Add to notification queue
                  messagesForNotification.add(newMsgMap);
                  print('📱 🔔 Queued message for notification - ID: $msgId');
                } else {
                  print('📱 Skipping duplicate message - ID: $msgId');
                }
              } else {
                print('📱 Skipping invalid message: ${newMsgMap}');
              }
            }
          });

          // Process notifications for new messages (outside setState)
          for (final messageData in messagesForNotification) {
            try {
              print(
                  '📱 🔔 Processing notification for message: ${messageData['id']}');
              await _showNotificationForMessage(messageData);
              print(
                  '📱 🔔 ✅ Notification sent successfully for message: ${messageData['id']}');
            } catch (e) {
              print(
                  '📱 🔔 ❌ Notification failed for message ${messageData['id']}: $e');
            }
          }

          // Maintain scroll position for new messages (WhatsApp-like behavior)
          if (hasNewMessages) {
            _maintainScrollPosition();
          }
        }

        // Update message statuses and read states in real-time
        final updatedStatuses =
            data['updated_statuses'] as List<dynamic>? ?? [];
        if (updatedStatuses.isNotEmpty) {
          setState(() {
            for (var statusUpdate in updatedStatuses) {
              final msgId = statusUpdate['id'];
              final newStatus = statusUpdate['status'];
              final isRead = statusUpdate['is_read'];

              final index = _messages.indexWhere((msg) => msg['id'] == msgId);
              if (index != -1) {
                // Update both status and read state for real-time blue checkmarks
                _messages[index]['status'] = newStatus;
                if (isRead != null) {
                  _messages[index]['is_read'] = isRead;
                  print(
                      'Chat: Real-time read status update - Message ID: $msgId, isRead: $isRead');
                }
              }
            }
          });
        }

        // Handle real-time read receipts separately (when admin opens client chat)
        final readReceipts = data['read_receipts'] as List<dynamic>? ?? [];
        if (readReceipts.isNotEmpty) {
          setState(() {
            for (var readUpdate in readReceipts) {
              final msgId = readUpdate['message_id'];
              final readAt = readUpdate['read_at'];

              final index = _messages.indexWhere((msg) => msg['id'] == msgId);
              if (index != -1) {
                _messages[index]['is_read'] = true;
                _messages[index]['read_at'] = readAt;
                print(
                    'Chat: Real-time read receipt - Message ID: $msgId marked as read');
              }
            }
          });
        }
      }
    } catch (e) {
      // Silent fail for polling - don't show errors to user
      // Error is logged but not displayed
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _sendMessage({String? message, File? file}) async {
    if (_isSending) return;

    if ((message?.trim().isEmpty ?? true) && file == null) return;

    final messageText = message?.trim() ?? '';
    final token = widget.token;

    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'Authentication token is missing. Please log in again.';
      });
      return;
    }

    // Clear input immediately for WhatsApp-like UX
    _messageController.clear();

    // Set sending state
    setState(() {
      _isSending = true;
    });

    try {
      // Use correct DRF send endpoints
      final sendEndpoints = [
        '/client/chat/send/', // Correct DRF endpoint
        '/drf/client/chat/send/', // Alternative with namespace
        '/api/client/chat/send/', // Fallback
      ];

      bool messageSent = false;
      String lastError = '';

      for (String endpoint in sendEndpoints) {
        try {
          final url = '${_apiService.baseUrl}$endpoint';

          http.Response response;

          if (file != null) {
            // Show uploading indicator for files
            if (mounted) {
              _showInfoMessage('📤 Uploading file...');
            }

            // Multipart form for files - matching MessageCreateSerializer
            final request = http.MultipartRequest('POST', Uri.parse(url));

            request.headers.addAll({
              'Authorization': 'Token $token',
              'Accept': 'application/json',
            });

            // Fields based on MessageCreateSerializer from chat_serializers.py
            // Always include content field (required by backend)
            request.fields['content'] =
                messageText.isNotEmpty ? messageText : '';
            request.fields['message_type'] = 'enquiry';

            // Add file with proper content type detection
            final mimeType =
                lookupMimeType(file.path) ?? 'application/octet-stream';
            request.files.add(
              await http.MultipartFile.fromPath(
                'file',
                file.path,
                contentType: MediaType.parse(mimeType),
              ),
            );

            final streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          } else {
            // JSON for text messages - matching MessageCreateSerializer
            response = await http.post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Token $token',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: json.encode({
                'content': messageText,
                'message_type': 'enquiry',
              }),
            );
          }

          if (response.statusCode == 201 || response.statusCode == 200) {
            // Success - message sent, real-time polling will pick it up
            _notifyMessageSent();

            // Trigger immediate poll for new message and start aggressive polling for read receipts
            _pollForNewMessages();
            _startAggressiveReadReceiptPolling();
            messageSent = true;
            break;
          } else if (response.statusCode == 400) {
            try {
              final errorData = json.decode(response.body);
              setState(() {
                _errorMessage =
                    'Validation error: ${errorData['errors'] ?? errorData['error'] ?? 'Invalid message data'}';
              });
            } catch (e) {
              setState(() {
                _errorMessage = 'Validation error: Invalid message data';
              });
            }
            return;
          } else if (response.statusCode == 401) {
            setState(() {
              _errorMessage = 'Authentication failed. Please log in again.';
            });
            return;
          } else if (response.statusCode == 403) {
            setState(() {
              _errorMessage =
                  'Access denied. You do not have permission to send messages.';
            });
            return;
          } else if (response.statusCode == 404) {
            lastError = 'Send endpoint $endpoint not found (404)';
            continue; // Try next endpoint
          } else {
            lastError =
                'Server error ${response.statusCode} from $endpoint: ${response.body}';
            continue; // Try next endpoint
          }
        } catch (e) {
          lastError = 'Connection error for $endpoint: $e';
          continue; // Try next endpoint
        }
      }

      if (!messageSent) {
        setState(() {
          _errorMessage =
              'Failed to send message to all endpoints. Last error: $lastError';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error sending message: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // Notify other parts of the app that a message was sent for instant badge updates
  void _notifyMessageSent() {
    if (mounted) {
      debugPrint(
          'Chat: Message sent successfully - badge boost should be triggered on return');
    }
  }

  // WhatsApp-style camera capture
  Future<void> _takePhotoAndSend() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (photo != null) {
        final file = File(photo.path);
        _showFilePreview(
          file: file,
          fileName: 'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg',
          fileType: 'image',
          fileSize: await file.length(),
        );
      }
    } catch (e) {
      _showErrorMessage('Camera error: ${e.toString()}');
    }
  }

  // WhatsApp-style gallery selection
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final file = File(image.path);
        final fileName = image.name.isNotEmpty
            ? image.name
            : 'Gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
        _showFilePreview(
          file: file,
          fileName: fileName,
          fileType: 'image',
          fileSize: await file.length(),
        );
      }
    } catch (e) {
      _showErrorMessage('Gallery error: ${e.toString()}');
    }
  }

  // WhatsApp-style document picker
  Future<void> _pickAndSendDocument() async {
    try {
      // Ensure we're still on the correct page before opening file picker
      if (!mounted) return;

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'rtf',
          'odt',
          'xls',
          'xlsx',
          'ppt',
          'pptx'
        ], // Only documents, no audio/video
        allowMultiple: false,
        allowCompression: true,
        withData:
            false, // Don't load file data immediately to improve performance
        withReadStream: false, // Don't use read stream
      );

      // Check if widget is still mounted after file picker returns
      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final fileName = result.files.first.name;
        final fileSize = result.files.first.size;

        // Check file size (25MB limit like WhatsApp)
        if (fileSize > 25 * 1024 * 1024) {
          if (mounted) {
            _showErrorMessage('File too large. Maximum size is 25MB.');
          }
          return;
        }

        // Show preview instead of sending immediately
        if (mounted) {
          _showFilePreview(
            file: file,
            fileName: fileName,
            fileType: _getFileTypeFromExtension(fileName),
            fileSize: fileSize,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Document selection cancelled or failed');
      }
    }
  }

  // Unified method for backward compatibility
  Future<void> _pickAndSendImage() async {
    await _pickImageFromGallery();
  }

  // Show WhatsApp-style file preview
  void _showFilePreview({
    required File file,
    required String fileName,
    required String fileType,
    required int fileSize,
  }) {
    setState(() {
      _previewFile = file;
      _previewFileName = fileName;
      _previewFileType = fileType;
      _previewFileSize = fileSize;
    });
  }

  // Clear file preview
  void _clearFilePreview() {
    setState(() {
      _previewFile = null;
      _previewFileName = null;
      _previewFileType = null;
      _previewFileSize = null;
    });
  }

  // Send the previewed file
  Future<void> _sendPreviewedFile() async {
    if (_previewFile == null) return;

    final fileDescription =
        _generateFileDescription(_previewFileName!, _previewFileSize!);
    await _sendMessage(file: _previewFile!, message: fileDescription);

    _clearFilePreview();
    _showSuccessMessage('📎 ${_previewFileName!} sent successfully!');
  }

  // Get file type from file extension
  String _getFileTypeFromExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return 'image';
      case 'pdf':
        return 'pdf';
      case 'doc':
      case 'docx':
        return 'document';
      case 'txt':
      case 'rtf':
      case 'odt':
        return 'text';
      case 'xls':
      case 'xlsx':
        return 'spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'presentation';
      default:
        return 'file';
    }
  }

  // Generate descriptive content for file uploads
  String _generateFileDescription(String fileName, int fileSize) {
    final fileSizeFormatted = _formatFileSize(fileSize);
    final fileExtension = fileName.split('.').last.toUpperCase();
    return 'Shared $fileExtension file: $fileName ($fileSizeFormatted)';
  }

  // Format file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Build beautiful WhatsApp-style file preview
  Widget _buildFilePreview() {
    if (_previewFile == null || _previewFileName == null)
      return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Container(
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 8 : 12,
        0,
        isSmallScreen ? 8 : 12,
        8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview header with close button
          Container(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 12 : 16,
              isSmallScreen ? 12 : 16,
              isSmallScreen ? 8 : 12,
              isSmallScreen ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file_rounded,
                  size: isSmallScreen ? 18 : 20,
                  color: const Color(0xFF128C7E),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Text(
                    'File Preview',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF128C7E),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _clearFilePreview,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: isSmallScreen ? 20 : 22,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // File preview content
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                // File preview thumbnail/icon
                _buildFilePreviewThumbnail(isSmallScreen),

                SizedBox(width: isSmallScreen ? 12 : 16),

                // File information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _previewFileName!,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF303030),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getFileIconColor(_previewFileType!)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _previewFileType!.toUpperCase(),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 11,
                                fontWeight: FontWeight.w600,
                                color: _getFileIconColor(_previewFileType!),
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Text(
                            _formatFileSize(_previewFileSize!),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(width: isSmallScreen ? 8 : 12),

                // Send button
                Material(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _isSending ? null : _sendPreviewedFile,
                    child: Container(
                      width: isSmallScreen ? 44 : 48,
                      height: isSmallScreen ? 44 : 48,
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 20 : 22,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Add caption input if needed (optional)
          Container(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 12 : 16,
              0,
              isSmallScreen ? 12 : 16,
              isSmallScreen ? 12 : 16,
            ),
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: isSmallScreen ? 13 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFF25D366), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: const Color(0xFF303030),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // Build file preview thumbnail
  Widget _buildFilePreviewThumbnail(bool isSmallScreen) {
    final thumbnailSize = isSmallScreen ? 56.0 : 64.0;

    if (_previewFileType == 'image') {
      // Show image thumbnail
      return Container(
        width: thumbnailSize,
        height: thumbnailSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.file(
            _previewFile!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultFileThumbnail(thumbnailSize);
            },
          ),
        ),
      );
    } else {
      // Show file type icon
      return _buildDefaultFileThumbnail(thumbnailSize);
    }
  }

  // Build default file thumbnail with icon
  Widget _buildDefaultFileThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getFileIconColor(_previewFileType!).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getFileIconColor(_previewFileType!).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        _getWhatsAppFileIcon(_previewFileType!),
        size: size * 0.4,
        color: _getFileIconColor(_previewFileType!),
      ),
    );
  }

  // Helper methods for user feedback
  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF25D366), // WhatsApp green
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showInfoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF128C7E),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _maintainScrollPosition() {
    if (_scrollController.hasClients && _messages.isNotEmpty) {
      // For reversed ListView, maintain position near 0 (latest messages)
      double currentPosition = _scrollController.position.pixels;

      // If user was at or near latest messages (position 0), keep them there
      if (currentPosition <= 100) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0.0);
          }
        });
      }
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        // More than a week ago - show date
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 1) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 5) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inMinutes > 0) {
        return 'Few minutes ago';
      } else {
        return 'Just now ✨';
      }
    } catch (e) {
      return timestamp;
    }
  }

  bool _isFromCurrentUser(Map<String, dynamic> message) {
    // Backend MessageListSerializer includes 'is_sender' field
    return message['is_sender'] == true;
  }

  Map<String, dynamic> _normalizeSupportMessage(Map<String, dynamic> message) {
    final normalized = Map<String, dynamic>.from(message);
    final deletedForEveryone = normalized['deleted_for_everyone'] == true;
    normalized['_deleted_for_everyone'] = deletedForEveryone;

    if (deletedForEveryone) {
      normalized['content'] = (normalized['content'] as String?) ??
          '';
      normalized['file_url'] = null;
      normalized['file_type'] = null;
      normalized['file'] = null;
    }

    normalized['_is_support_sender'] = normalized['is_support_sender'] == true;
    normalized['_sender_avatar'] = normalized['sender_avatar']?.toString();
    normalized['_sender_initials'] = normalized['sender_initials']?.toString();
    normalized['_sender_name'] = normalized['sender_name']?.toString();
    
    return normalized;
  }

  bool _isValidBackendMessage(Map<String, dynamic> message) {
    return message.containsKey('id') &&
        message.containsKey('content') &&
        message.containsKey('date_sent');
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isFromMe = _isFromCurrentUser(message);
    final hasFile = message['file_url'] != null &&
        message['file_url'].toString().isNotEmpty;
    final content = message['content']?.toString() ?? '';

    // Use support serializer fields for avatars
    final profileImageUrl = isFromMe
        ? (_currentUserProfileImageUrl?.isNotEmpty == true
            ? _currentUserProfileImageUrl
            : message['_sender_avatar']?.toString())
        : message['_sender_avatar']?.toString();

    // Responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final avatarSize = isSmallScreen ? 32.0 : 36.0;
    final bubbleMaxWidth = screenWidth * (isSmallScreen ? 0.82 : 0.75);
    final horizontalPadding = isSmallScreen ? 8.0 : 12.0;
    final verticalPadding = isSmallScreen ? 4.0 : 6.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Admin/Sender Avatar (left side)
          if (!isFromMe) ...[
            _buildProfileAvatar(
              profileImageUrl: profileImageUrl,
              isAdmin: message['_is_support_sender'] == true,

              size: avatarSize,
              heroTag: 'admin_avatar_${message['id']}',
            ),
            SizedBox(width: horizontalPadding),
          ],

          // Message Bubble
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bubbleMaxWidth,
                minWidth: 60,
              ),
              child: GestureDetector(
                onLongPress: message['_deleted_for_everyone'] == true
                    ? null
                    : () => _showMessageOptions(message),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: isFromMe ? const Color(0xFF128C7E) : Colors.white,
                    borderRadius: _buildWhatsAppBorderRadius(isFromMe),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                        spreadRadius: 0,
                      ),
                    ],
                    border: !isFromMe
                        ? Border.all(color: const Color(0xFFE5E5E5), width: 1)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: _buildWhatsAppBorderRadius(isFromMe),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 6 : 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // File attachment
                          if (hasFile) ...[
                            _buildWhatsAppFileAttachment(message, isFromMe),
                            if (content.isNotEmpty)
                              SizedBox(height: isSmallScreen ? 4 : 6),
                          ],

                          // Message content
                          if (content.isNotEmpty)
                            _buildWhatsAppMessageContent(
                                message, isFromMe, content),

                          // Message footer (time & status)
                          SizedBox(height: isSmallScreen ? 2 : 4),
                          _buildWhatsAppMessageFooter(message, isFromMe),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // User Avatar (right side)
          if (isFromMe) ...[
            SizedBox(width: horizontalPadding),
            _buildProfileAvatar(
              profileImageUrl: profileImageUrl,
              isAdmin: false,
              size: avatarSize,
              heroTag: 'user_avatar_${message['id']}',
            ),
          ],
        ],
      ),
    );
  }

  // WhatsApp-style border radius
  BorderRadius _buildWhatsAppBorderRadius(bool isFromMe) {
    return BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isFromMe ? 18 : 4),
      bottomRight: Radius.circular(isFromMe ? 4 : 18),
    );
  }

  // Responsive profile avatar with fallbacks
  Widget _buildProfileAvatar({
    String? profileImageUrl,
    required bool isAdmin,
    required double size,
    required String heroTag,
  }) {
    return Hero(
      tag: heroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: profileImageUrl != null && profileImageUrl.isNotEmpty
              ? _buildNetworkProfileImage(profileImageUrl, size, isAdmin)
              : _buildDefaultProfileAvatar(isAdmin, size),
        ),
      ),
    );
  }

  // Network profile image with error handling and debugging
  Widget _buildNetworkProfileImage(String imageUrl, double size, bool isAdmin) {
    // Debug: Log image URL being loaded
    print(
        'Chat: Loading profile image - URL: $imageUrl, isAdmin: $isAdmin, size: $size');

    return Image.network(
      imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          print('Chat: Profile image loaded successfully: $imageUrl');
          return child;
        }
        print(
            'Chat: Loading profile image progress: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
        return Container(
          width: size,
          height: size,
          color: Colors.grey[100],
          child: Center(
            child: SizedBox(
              width: size * 0.4,
              height: size * 0.4,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  isAdmin ? const Color(0xFF128C7E) : Colors.blue,
                ),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('Chat: Error loading profile image: $imageUrl - Error: $error');
        return _buildDefaultProfileAvatar(isAdmin, size);
      },
    );
  }

  // Default profile avatar (fallback)
  Widget _buildDefaultProfileAvatar(bool isAdmin, double size) {
    if (isAdmin) {
      // Use logo.png for admin
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // For client users, keep the existing gradient design
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  // WhatsApp-style message content
  Widget _buildWhatsAppMessageContent(
      Map<String, dynamic> message, bool isFromMe, String content) {
    final isDeleted = message['_deleted_for_everyone'] == true;
    final isDeleting = message['_deleting'] == true;
    final isStarred = message['is_starred'] == true;
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 14.0 : 16.0;

    if (isDeleting) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                isFromMe ? Colors.white70 : Colors.grey[600]!,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Deleting...',
            style: TextStyle(
              color: isFromMe ? Colors.white70 : Colors.grey[600],
              fontSize: fontSize - 2,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    if (isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.block_rounded,
            size: 14,
            color: isFromMe ? Colors.white60 : Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              content.startsWith('🚫')
                  ? content
                  : '🚫 This message was deleted',
              style: TextStyle(
                color: isFromMe ? Colors.white70 : Colors.grey[600],
                fontSize: fontSize - 2,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isStarred)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: isFromMe ? Colors.white70 : Colors.amber[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Starred',
                  style: TextStyle(
                    color: isFromMe ? Colors.white70 : Colors.grey[600],
                    fontSize: fontSize - 4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        SelectableText(
          content,
          style: TextStyle(
            color: isFromMe ? Colors.white : const Color(0xFF303030),
            fontSize: fontSize,
            height: 1.3,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // WhatsApp-style message footer (time + status)
  Widget _buildWhatsAppMessageFooter(
      Map<String, dynamic> message, bool isFromMe) {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 11.0 : 12.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Delete warning
        if (isFromMe && _shouldShowDeleteWarning(message)) ...[
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: isFromMe ? Colors.white60 : Colors.orange[600],
          ),
          const SizedBox(width: 4),
        ],

        // Timestamp
        Text(
          _formatTimestamp(message['date_sent']?.toString() ?? ''),
          style: TextStyle(
            color: isFromMe ? Colors.white70 : Colors.grey[500],
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
          ),
        ),

        // Message status for sent messages
        if (isFromMe) ...[
          const SizedBox(width: 4),
          _buildWhatsAppMessageStatus(message),
        ],
      ],
    );
  }

  // WhatsApp-style message status indicators (real-time read receipts)
  Widget _buildWhatsAppMessageStatus(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'sent';
    final isRead = message['is_read'] == true;

    // Priority: is_read field takes precedence for real-time blue checkmarks
    if (isRead) {
      // Message has been read by admin - show blue double checkmarks
      return Icon(
        Icons.done_all_rounded,
        size: 16,
        color: const Color(0xFF4FC3F7), // WhatsApp blue
      );
    }

    IconData icon;
    Color color;

    switch (status.toLowerCase()) {
      case 'sending':
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case 'sent':
        icon = Icons.done_rounded; // Single checkmark
        color = Colors.white60;
        break;
      case 'delivered':
        icon = Icons.done_all_rounded; // Double checkmark (gray)
        color = Colors.white60;
        break;
      case 'read':
        // This case might be redundant since we check is_read above, but keep for safety
        icon = Icons.done_all_rounded;
        color = const Color(0xFF4FC3F7); // WhatsApp blue
        break;
      default:
        // Fallback based on delivery status
        icon = (status == 'delivered' || status == 'read')
            ? Icons.done_all_rounded
            : Icons.done_rounded;
        color = Colors.white60;
    }

    return Icon(icon, size: 16, color: color);
  }

  // WhatsApp-style file attachment
  Widget _buildWhatsAppFileAttachment(
      Map<String, dynamic> message, bool isFromMe) {
    final fileUrl = message['file_url']?.toString();
    final fileType = message['file_type']?.toString() ?? 'file';
    final fileName = _getFileName(fileUrl ?? '');
    final fileId = message['id']?.toString() ?? fileUrl ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    if (fileUrl == null) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth * 0.6,
        minHeight: isSmallScreen ? 50 : 60,
      ),
      decoration: BoxDecoration(
        color:
            isFromMe ? Colors.white.withOpacity(0.1) : const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: !isFromMe ? Border.all(color: const Color(0xFFE5E5E5)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleFileTap(fileId, fileUrl, fileName),
          onLongPress: () => _openDownloadedAttachment(fileId, fileName, fileUrl),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: Row(
              children: [
                _buildAttachmentLeading(fileType, isSmallScreen, fileId, isFromMe),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          color: isFromMe ? Colors.white : const Color(0xFF303030),
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      _buildAttachmentMetaRow(fileType, isSmallScreen, isFromMe, fileId),
                    ],
                  ),
                ),
                _buildAttachmentAction(fileId, isFromMe, isSmallScreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Get WhatsApp-style file icon
  IconData _getWhatsAppFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return Icons.image_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'document':
        return Icons.description_rounded;
      case 'text':
        return Icons.text_snippet_rounded;
      case 'spreadsheet':
        return Icons.table_chart_rounded;
      case 'presentation':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  // Get file icon color
  Color _getFileIconColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'image':
        return Colors.purple[400]!;
      case 'pdf':
        return Colors.red[400]!;
      case 'document':
        return Colors.blue[400]!;
      case 'text':
        return Colors.teal[400]!;
      case 'spreadsheet':
        return Colors.green[400]!;
      case 'presentation':
        return Colors.orange[400]!;
      default:
        return Colors.grey[500]!;
    }
  }

  Widget _buildAttachmentLeading(String fileType, bool isSmallScreen, String fileId, bool isFromMe) {
    final progress = _downloadProgress[fileId];
    final completed = _downloadCompleted[fileId] == true;
    if (progress != null && progress < 1.0) {
      return SizedBox(
        width: isSmallScreen ? 32 : 40,
        height: isSmallScreen ? 32 : 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                isFromMe ? Colors.white : const Color(0xFF128C7E),
              ),
              backgroundColor: isFromMe ? Colors.white24 : Colors.grey[200]!,
            ),
            Icon(
              Icons.downloading_rounded,
              size: isSmallScreen ? 18 : 20,
              color: isFromMe ? Colors.white : const Color(0xFF128C7E),
            ),
          ],
        ),
      );
    }

    if (completed) {
      return Container(
        width: isSmallScreen ? 32 : 40,
        height: isSmallScreen ? 32 : 40,
        decoration: BoxDecoration(
          color: (isFromMe ? Colors.white24 : const Color(0xFFE8F5E9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.check_circle_rounded,
          size: isSmallScreen ? 20 : 22,
          color: isFromMe ? Colors.white : const Color(0xFF2E7D32),
        ),
      );
    }

    return Container(
      width: isSmallScreen ? 32 : 40,
      height: isSmallScreen ? 32 : 40,
      decoration: BoxDecoration(
        color: _getFileIconColor(fileType),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getWhatsAppFileIcon(fileType),
        size: isSmallScreen ? 18 : 22,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAttachmentMetaRow(String fileType, bool isSmallScreen, bool isFromMe, String fileId) {
    final progress = _downloadProgress[fileId];
    final completed = _downloadCompleted[fileId] == true;
    if (progress != null && progress < 1.0) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isFromMe ? Colors.white : const Color(0xFF128C7E),
                ),
                backgroundColor: isFromMe ? Colors.white24 : Colors.grey[300]!,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: isFromMe ? Colors.white70 : Colors.grey[600],
              fontSize: isSmallScreen ? 10 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(
          fileType.toUpperCase(),
          style: TextStyle(
            color: isFromMe ? Colors.white70 : Colors.grey[600],
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          completed ? Icons.check_rounded : Icons.file_download_rounded,
          size: isSmallScreen ? 12 : 14,
          color: isFromMe ? Colors.white70 : Colors.grey[600],
        ),
      ],
    );
  }

  Widget _buildAttachmentAction(String fileId, bool isFromMe, bool isSmallScreen) {
    final progress = _downloadProgress[fileId];
    final completed = _downloadCompleted[fileId] == true;

    if (progress != null && progress < 1.0) {
      return SizedBox(
        width: isSmallScreen ? 24 : 28,
        height: isSmallScreen ? 24 : 28,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: isSmallScreen ? 18 : 20,
          icon: Icon(
            Icons.close_rounded,
            color: isFromMe ? Colors.white70 : Colors.grey[600],
          ),
          onPressed: () => _cancelDownload(fileId),
        ),
      );
    }

    return Icon(
      completed ? Icons.check_circle_outline_rounded : Icons.file_download_outlined,
      size: isSmallScreen ? 18 : 20,
      color: isFromMe
          ? (completed ? Colors.white : Colors.white70)
          : (completed ? const Color(0xFF2E7D32) : Colors.grey[600]),
    );
  }

  void _handleFileTap(String fileId, String? fileUrl, String fileName) {
    if (fileUrl == null || fileUrl.isEmpty) {
      _showErrorMessage('File URL unavailable');
      return;
    }

    if (_downloadCompleted[fileId] == true) {
      _openDownloadedAttachment(fileId, fileName, fileUrl);
      return;
    }

    final currentProgress = _downloadProgress[fileId];
    if (currentProgress != null && currentProgress < 1.0) {
      // Already downloading
      return;
    }

    _startInlineDownload(fileId, fileUrl, fileName);
  }

  void _startInlineDownload(String fileId, String fileUrl, String fileName, {bool forceRefresh = false}) async {
    setState(() {
      _downloadProgress[fileId] = 0.0;
      _downloadCompleted[fileId] = false;
      _downloadCancelFlags[fileId] = false;
      if (forceRefresh) {
        _downloadedFilePaths.remove(fileId);
        _downloadCache.removeEntry(_downloadNamespace, fileId);
      }
    });

    final notificationService = NotificationService();
    final notificationId = await notificationService.showDownloadNotification(fileName);
    if (notificationId != null) {
      _downloadNotificationIds[fileId] = notificationId;
    }

    try {
      final path = await downloadFileWithProgress(
        filename: fileName,
        url: fileUrl,
        onProgress: (received, total) {
          if (!mounted || total == 0) return;
          setState(() {
            _downloadProgress[fileId] = received / total;
          });
          if (notificationId != null && total > 0) {
            notificationService.updateDownloadNotification(
              notificationId: notificationId,
              fileName: fileName,
              progress: received / total,
            );
          }
        },
        shouldCancel: () => _downloadCancelFlags[fileId] == true,
      );

      if (!mounted) return;

      if (path == null) {
        setState(() {
          _downloadProgress.remove(fileId);
          _downloadCompleted.remove(fileId);
          _downloadCancelFlags.remove(fileId);
        });
        _showInfoMessage('Download cancelled');
        final id = notificationId ?? _downloadNotificationIds.remove(fileId);
        if (id != null) {
          await notificationService.cancelDownloadNotification(id);
        }
        return;
      }

      setState(() {
        _downloadProgress[fileId] = 1.0;
        _downloadCompleted[fileId] = true;
        _downloadedFilePaths[fileId] = path;
        _downloadCancelFlags.remove(fileId);
      });
      await _downloadCache.saveEntry(_downloadNamespace, fileId, path);

      _showSuccessMessage('✅ Saved $fileName');
      final id = notificationId ?? _downloadNotificationIds[fileId];
      if (id != null) {
        await notificationService.completeDownloadNotification(
          notificationId: id,
          fileName: fileName,
          filePath: path,
          fileUrl: fileUrl,
        );
      }
      if (notificationId != null) {
        _downloadNotificationIds.remove(fileId);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _downloadProgress.remove(fileId);
        _downloadCompleted.remove(fileId);
        _downloadCancelFlags.remove(fileId);
        _downloadedFilePaths.remove(fileId);
      });

      _showErrorMessage('Failed to download: $e');
      final id = notificationId ?? _downloadNotificationIds.remove(fileId);
      if (id != null) {
        await notificationService.failDownloadNotification(
          notificationId: id,
          fileName: fileName,
          reason: e.toString(),
        );
      }
      await _downloadCache.removeEntry(_downloadNamespace, fileId);
    }
  }

  void _cancelDownload(String fileId) {
    setState(() {
      _downloadCancelFlags[fileId] = true;
      _downloadProgress.remove(fileId);
      _downloadCompleted.remove(fileId);
      _downloadedFilePaths.remove(fileId);
    });
    final id = _downloadNotificationIds.remove(fileId);
    if (id != null) {
      NotificationService().cancelDownloadNotification(id);
    }
    _downloadCache.removeEntry(_downloadNamespace, fileId);
  }

  Future<void> _openDownloadedAttachment(String fileId, String fileName, String? fileUrl) async {
    final path = _downloadedFilePaths[fileId];
    if (path == null || path.isEmpty) {
      if (fileUrl != null && fileUrl.isNotEmpty) {
        _showInfoMessage('Opening $fileName...');
        _startInlineDownload(fileId, fileUrl, fileName, forceRefresh: true);
      } else {
        _showErrorMessage('File is no longer available.');
      }
      return;
    }

    if (!kIsWeb) {
      final file = File(path);
      final exists = await file.exists();
      if (!exists) {
        await _downloadCache.removeEntry(_downloadNamespace, fileId);
        setState(() {
          _downloadCompleted.remove(fileId);
          _downloadedFilePaths.remove(fileId);
        });
        if (fileUrl != null && fileUrl.isNotEmpty) {
          _showInfoMessage('Re-downloading $fileName...');
          _startInlineDownload(fileId, fileUrl, fileName, forceRefresh: true);
        } else {
          _showErrorMessage('File is no longer available.');
        }
        return;
      }
    }

    try {
      await openDownloadedFile(path, fallbackUrl: fileUrl);
    } catch (e) {
      _showErrorMessage('Unable to open file: $e');
    }
  }

  // Show image preview in photo viewer
  void _showImagePreview(String imageUrl, String fileName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
            title: Text(
              fileName,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () async {
                  try {
                    _showInfoMessage('⬇️ Downloading $fileName...');
                    await downloadFile(fileName, imageUrl);
                    _showSuccessMessage('✅ Saved $fileName');
                  } catch (e) {
                    _showErrorMessage('Failed to download: $e');
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF25D366),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show file information dialog
  void _showFileInfoDialog(String fileUrl, String fileName, String fileType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _getWhatsAppFileIcon(fileType),
              color: _getFileIconColor(fileType),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Type: ${fileType.toUpperCase()}'),
            const SizedBox(height: 8),
            Text('URL: $fileUrl'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF128C7E)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                _showInfoMessage('⬇️ Downloading $fileName...');
                await downloadFile(fileName, fileUrl);
                _showSuccessMessage('✅ Saved $fileName');
              } catch (e) {
                _showErrorMessage('Failed to download: $e');
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  // Check if file is an image
  bool _isImageFile(String fileType) {
    final imageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    return imageTypes.contains(fileType.toLowerCase());
  }

  // Get file type from URL
  String _getFileTypeFromUrl(String fileUrl) {
    try {
      final uri = Uri.parse(fileUrl);
      final path = uri.path.toLowerCase();
      final extension = path.split('.').last;
      return extension.isNotEmpty ? extension : 'file';
    } catch (e) {
      return 'file';
    }
  }

  String _getFileName(String fileUrl) {
    try {
      return fileUrl.split('/').last.split('?').first;
    } catch (e) {
      return 'Attachment';
    }
  }

  // Show beautiful message details dialog

  // WhatsApp-style message options (long press)
  void _showMessageOptions(Map<String, dynamic> message) {
    final isFromMe = _isFromCurrentUser(message);
    final messageTime = DateTime.tryParse(message['date_sent'] ?? '');
    final canDeleteForEveryone = _canDeleteForEveryone(messageTime, isFromMe);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    HapticFeedback.mediumImpact(); // WhatsApp-style haptic feedback

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(
                top: isSmallScreen ? 8 : 12,
                bottom: isSmallScreen ? 8 : 12,
              ),
              width: isSmallScreen ? 36 : 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[350],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Selected message preview
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF128C7E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: const Color(0xFF128C7E),
                      size: isSmallScreen ? 16 : 18,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: Text(
                      message['content'] ?? 'Media message',
                      style: TextStyle(
                        color: const Color(0xFF495057),
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Delete Options Only
            if (isFromMe)
              Flexible(
                child: Column(
                  children: [
                    // Delete for me (always available for own messages)
                    _buildResponsiveOptionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Delete for me',
                      subtitle: 'Remove from this device only',
                      color: Colors.red[600]!,
                      isSmallScreen: isSmallScreen,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteMessageForMe(message);
                      },
                    ),

                    // Delete for everyone (only available within 24 hours for own messages)
                    if (canDeleteForEveryone)
                      _buildResponsiveOptionTile(
                        icon: Icons.delete_forever_rounded,
                        title: 'Delete for everyone',
                        subtitle: 'Remove for all participants',
                        color: Colors.red[700]!,
                        isSmallScreen: isSmallScreen,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDeleteForEveryone(message);
                        },
                      ),
                  ],
                ),
              )
            else
              // No options for received messages
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.grey[400],
                      size: isSmallScreen ? 32 : 36,
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Text(
                      'No actions available',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You can only delete your own messages',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(height: isSmallScreen ? 16 : 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isSmallScreen,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 40 : 44,
                  height: isSmallScreen ? 40 : 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isSmallScreen ? 20 : 22,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: isSmallScreen ? 15 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey[400],
                  size: isSmallScreen ? 14 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Check if message can be deleted for everyone (WhatsApp: 1 hour 8 minutes and 16 seconds, but commonly known as ~1 hour)
  // For simplicity, we'll use 24 hours as you requested, but WhatsApp actually uses ~1 hour
  bool _canDeleteForEveryone(DateTime? messageTime, bool isFromMe) {
    if (!isFromMe || messageTime == null) return false;

    final now = DateTime.now();
    final timeDifference = now.difference(messageTime);

    // WhatsApp allows deletion for everyone within approximately 1 hour, 8 minutes, and 16 seconds
    // But you requested 24 hours, so let's use that
    return timeDifference.inHours < 24;
  }

  // Reply to a message

  // Delete message for me only (local deletion)
  void _deleteMessageForMe(Map<String, dynamic> message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenWidth * 0.9 : 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Title
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.red[100]!, width: 2),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red[600],
                  size: isSmallScreen ? 28 : 32,
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),

              Text(
                'Delete for me',
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),

              // Description
              Flexible(
                child: Text(
                  'This message will be deleted from your device only. Other participants will still see it.',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: const Color(0xFF666666),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: isSmallScreen ? 24 : 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _messages
                              .removeWhere((msg) => msg['id'] == message['id']);
                        });

                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Message deleted',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Confirm delete for everyone
  void _confirmDeleteForEveryone(Map<String, dynamic> message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final messageTime = DateTime.tryParse(message['date_sent'] ?? '');
    final timeRemaining = messageTime != null
        ? Duration(hours: 24) - DateTime.now().difference(messageTime)
        : Duration.zero;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenWidth * 0.9 : 420,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Title
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.red[100]!, width: 2),
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red[600],
                  size: isSmallScreen ? 28 : 32,
                ),
              ),
              SizedBox(height: isSmallScreen ? 16 : 20),

              Text(
                'Delete for everyone',
                style: TextStyle(
                  fontSize: isSmallScreen ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),

              // Description
              Flexible(
                child: Text(
                  'This message will be deleted for all participants in this chat.',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    color: const Color(0xFF666666),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Time remaining warning
              if (timeRemaining.inMinutes > 0) ...[
                SizedBox(height: isSmallScreen ? 16 : 20),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: Colors.orange[700],
                        size: isSmallScreen ? 18 : 20,
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time remaining',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: isSmallScreen ? 12 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${timeRemaining.inHours}h ${timeRemaining.inMinutes % 60}m',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: isSmallScreen ? 24 : 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    flex: isSmallScreen ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteMessageForEveryone(message);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete for everyone',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Delete message for everyone (API call)
  Future<void> _deleteMessageForEveryone(Map<String, dynamic> message) async {
    try {
      final messageId = message['id'];
      final token = widget.token;

      if (token.isEmpty) {
        _showErrorSnackBar('Authentication token missing');
        return;
      }

      // Show loading state
      setState(() {
        message['_deleting'] = true;
      });

      // API call to delete message for everyone
      final url = '${_apiService.baseUrl}/client/chat/delete-for-everyone/';
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Token $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'message_id': messageId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>?;
        final updatedMessage = responseData?['message'] as Map<String, dynamic>?;

        setState(() {
          if (updatedMessage != null) {
            message['content'] = updatedMessage['content'] ?? '🚫 This message was deleted';
            message['_deleted_for_everyone'] = updatedMessage['deleted_for_everyone'] == true;
            message['file_url'] = updatedMessage['file_url'];
            message['file_type'] = updatedMessage['file_type'];
            message['deleted_for_everyone_at'] = updatedMessage['deleted_for_everyone_at'];
          } else {
            message['content'] = '🚫 This message was deleted';
            message['_deleted_for_everyone'] = true;
            message['file_url'] = null;
          }
          message['_deleting'] = false;
        });

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted for everyone'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 403) {
        setState(() {
          message['_deleting'] = false;
        });
        _showErrorSnackBar(
            'Cannot delete message: Time limit exceeded (24 hours)');
      } else if (response.statusCode == 404) {
        setState(() {
          message['_deleting'] = false;
        });
        _showErrorSnackBar('Message not found or already deleted');
      } else {
        setState(() {
          message['_deleting'] = false;
        });
        try {
          final errorData = json.decode(response.body) as Map<String, dynamic>;
          final error = errorData['error']?.toString();
          if (error != null && error.isNotEmpty) {
            _showErrorSnackBar(error);
            return;
          }
        } catch (_) {}
        _showErrorSnackBar('Failed to delete message: Server error');
      }
    } catch (e) {
      setState(() {
        message['_deleting'] = false;
      });
      _showErrorSnackBar('Network error: Could not delete message');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[600],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildMessageInput() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom > 0
        ? 8.0
        : MediaQuery.of(context).padding.bottom + 8;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 8 : 12,
        isSmallScreen ? 8 : 12,
        isSmallScreen ? 8 : 12,
        bottomPadding,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7), // WhatsApp input background
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E5E5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button (disabled when file is being previewed)
          if (!_isSending && _previewFile == null)
            IconButton(
              onPressed: () => _showAttachmentOptions(),
              icon: Icon(
                Icons.attach_file_rounded,
                color: Colors.grey[600],
                size: isSmallScreen ? 22 : 24,
              ),
              constraints: BoxConstraints(
                minWidth: isSmallScreen ? 40 : 44,
                minHeight: isSmallScreen ? 40 : 44,
              ),
              padding: const EdgeInsets.all(8),
            ),

          // Message input container
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFFE5E5E5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Emoji button
                  IconButton(
                    onPressed: () => _showEmojiPicker(),
                    icon: Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.grey[600],
                      size: isSmallScreen ? 20 : 22,
                    ),
                    constraints: BoxConstraints(
                      minWidth: isSmallScreen ? 36 : 40,
                      minHeight: isSmallScreen ? 36 : 40,
                    ),
                    padding: const EdgeInsets.all(6),
                  ),

                  // Text input field
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screenWidth < 360 ? 80 : 100,
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Message',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8 : 12,
                            horizontal: 4,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF303030),
                        ),
                        maxLines: isSmallScreen ? 4 : 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty && !_isSending) {
                            HapticFeedback.lightImpact();
                            _sendMessage(message: value);
                          }
                        },
                      ),
                    ),
                  ),

                  // Camera button
                  if (_messageController.text.trim().isEmpty)
                    IconButton(
                      onPressed: _isSending ? null : () => _pickAndSendImage(),
                      icon: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.grey[600],
                        size: isSmallScreen ? 20 : 22,
                      ),
                      constraints: BoxConstraints(
                        minWidth: isSmallScreen ? 36 : 40,
                        minHeight: isSmallScreen ? 36 : 40,
                      ),
                      padding: const EdgeInsets.all(6),
                    ),
                ],
              ),
            ),
          ),

          // Send button
          Container(
            margin: const EdgeInsets.only(left: 4, bottom: 4),
            child: _buildSendButton(isSmallScreen),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(MediaQuery.of(context).size.width < 360 ? 65 : 75),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF128C7E), // WhatsApp green
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            title: Row(
              children: [
                Hero(
                  tag: 'admin_avatar_header',
                  child: Stack(
                    children: [
                      Container(
                        width:
                            MediaQuery.of(context).size.width < 360 ? 42 : 48,
                        height:
                            MediaQuery.of(context).size.width < 360 ? 42 : 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.width < 360
                                  ? 21
                                  : 24),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                              MediaQuery.of(context).size.width < 360
                                  ? 21
                                  : 24),
                          child: Image.asset(
                            'assets/logo.png',
                            width: MediaQuery.of(context).size.width < 360
                                ? 36
                                : 42,
                            height: MediaQuery.of(context).size.width < 360
                                ? 36
                                : 42,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Online indicator
                      if (_isPolling || !_isLoading)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: MediaQuery.of(context).size.width < 360
                                ? 12
                                : 16,
                            height: MediaQuery.of(context).size.width < 360
                                ? 12
                                : 16,
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              borderRadius: BorderRadius.circular(
                                  MediaQuery.of(context).size.width < 360
                                      ? 6
                                      : 8),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Admin Support',
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 360 ? 17 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: (_isPolling || !_isLoading)
                                  ? Colors.green[400]
                                  : Colors.orange[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _isPolling || !_isLoading
                                  ? 'Active • Responds instantly'
                                  : 'Connecting...',
                              style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 360
                                        ? 11
                                        : 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Notification test button (for debugging)
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/test-notifications');
                },
                icon: const Icon(
                  Icons.bug_report,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: 'Test Notifications',
              ),
              // Notification settings button
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _showNotificationSettings();
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              // Refresh messages button
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _loadMessages();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Beautiful error banner
          if (_errorMessage != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[400]!, Colors.red[600]!],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),

          // Main chat area with gradient background
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[50]!,
                    Colors.white,
                    Colors.grey[50]!,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: _isLoading
                  ? _buildLoadingState()
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(),
            ),
          ),
          // WhatsApp-style file preview (shows above input when file is selected)
          if (_previewFile != null) _buildFilePreview(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading your messages...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Setting up secure connection',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[100]!, Colors.purple[100]!],
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Admin Support!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start a conversation with our expert team',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re here to help you 24/7 ✨',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_downward_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Type your message below',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
      itemCount: _messages.length,
      reverse: true, // Latest messages at bottom
      cacheExtent: 500, // Cache more items for smoother scrolling
      addAutomaticKeepAlives: true, // Keep widgets alive for better performance
      itemBuilder: (context, index) {
        final messageIndex = _messages.length - 1 - index;
        // Reduced animation duration for better performance
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: _buildMessageBubble(_messages[messageIndex]),
        );
      },
    );
  }

  // Check if we should show delete warning (within 2 hours of 24-hour limit)
  bool _shouldShowDeleteWarning(Map<String, dynamic> message) {
    final messageTime = DateTime.tryParse(message['date_sent'] ?? '');
    if (messageTime == null || message['_deleted_for_everyone'] == true)
      return false;

    final now = DateTime.now();
    final timeDifference = now.difference(messageTime);

    // Show warning if message is between 22-24 hours old (within 2 hours of expiry)
    return timeDifference.inHours >= 22 && timeDifference.inHours < 24;
  }

  // WhatsApp-style attachment options
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // WhatsApp-style comprehensive attachment picker
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // First row - Camera, Gallery, Document
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: const Color(0xFF25D366), // WhatsApp green
                        onTap: () {
                          Navigator.pop(context);
                          _takePhotoAndSend();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: const Color(0xFF7C4DFF), // Purple
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromGallery();
                        },
                      ),
                      _buildAttachmentOption(
                        icon: Icons.insert_drive_file_rounded,
                        label: 'Document',
                        color: const Color(0xFF2196F3), // Blue
                        onTap: () async {
                          Navigator.pop(context);
                          // Add small delay to ensure modal is fully closed
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          _pickAndSendDocument();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF303030),
            ),
          ),
        ],
      ),
    );
  }

  // Emoji picker (placeholder)
  void _showEmojiPicker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emoji picker coming soon! 😊'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF128C7E),
      ),
    );
  }

  // WhatsApp-style send button
  Widget _buildSendButton(bool isSmallScreen) {
    return GestureDetector(
      onTap: _isSending
          ? null
          : () {
              if (_previewFile != null) {
                // Send the previewed file
                HapticFeedback.lightImpact();
                _sendPreviewedFile();
              } else if (_messageController.text.trim().isNotEmpty) {
                // Send text message
                HapticFeedback.lightImpact();
                _sendMessage(message: _messageController.text);
              }
            },
      child: Container(
        width: isSmallScreen ? 44 : 48,
        height: isSmallScreen ? 44 : 48,
        decoration: const BoxDecoration(
          color: Color(0xFF128C7E), // WhatsApp green
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: _isSending
            ? SizedBox(
                width: isSmallScreen ? 20 : 24,
                height: isSmallScreen ? 20 : 24,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: isSmallScreen ? 20 : 22,
              ),
      ),
    );
  }
}
