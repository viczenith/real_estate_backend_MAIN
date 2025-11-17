import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:real_estate_app/admin/download_files/file_downloader.dart'
    as file_downloader;
import 'package:real_estate_app/services/download_cache.dart';
import 'package:real_estate_app/services/notification_service.dart';
import 'package:real_estate_app/services/push_notification_service.dart';
import 'package:real_estate_app/shared/app_layout.dart';

import 'chat_role_config.dart';

/// A reusable WhatsApp-style chat page that can serve clients, marketers and
/// admin-support staff. It reuses the modern UI/experience from the marketer
/// chat screen but delegates all role-specific logic (API calls, message
/// normalisation, push matching, etc.) to [ChatRoleConfig].
class SharedChatThreadPage extends StatefulWidget {
  const SharedChatThreadPage({
    super.key,
    required this.token,
    required this.config,
    this.participant,
    this.pageTitle,
  });

  final String token;
  final ChatRoleConfig config;
  final ChatParticipantContext? participant;
  final String? pageTitle;

  @override
  State<SharedChatThreadPage> createState() => _SharedChatThreadPageState();
}

class _SharedChatThreadPageState extends State<SharedChatThreadPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final NotificationService _notificationService = NotificationService();
  AudioPlayer? _audioPlayer;
  Uint8List? _incomingToneBytes;
  Uint8List? _outgoingToneBytes;

  StreamSubscription<Map<String, dynamic>>? _pushSubscription;
  Timer? _pollingTimer;

  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  final Map<String, double> _downloadProgress = <String, double>{};
  final Map<String, bool> _downloadCompleted = <String, bool>{};
  final Map<String, bool> _downloadCancelFlags = <String, bool>{};
  final Map<String, String> _downloadedFilePaths = <String, String>{};
  final Map<String, int> _downloadNotificationIds = <String, int>{};
  final DownloadCache _downloadCache = DownloadCache();
  final Map<int, String> _localFileHints = <int, String>{};
  final Map<int, String> _localFileNames = <int, String>{};

  bool _isLoading = true;
  bool _isSending = false;
  bool _isPolling = false;
  String? _errorMessage;
  bool _isUserScrolledUp = false;
  int _pendingNewMessageCount = 0;

  ChatParticipantContext? _participant;
  String? _currentUserAvatar;
  int _lastMessageId = 0;

  File? _pendingFile;
  String? _pendingFileName;
  String? _pendingFileType;
  int? _pendingFileSize;

  late final String _downloadNamespace;

  ChatRoleConfig get _config => widget.config;
  String get _token => widget.token;

  @override
  void initState() {
    super.initState();
    _participant = widget.participant;
    _downloadNamespace =
        _config.downloadNamespaceBuilder(widget.participant ?? _participant);

    unawaited(_notificationService.initialize());
    _initializeChatData();
    _subscribeToPushMessages();
    _startPolling();
    _loadCachedDownloads();

    _messageController.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScrollChanged);
  }

  void _maybePlayIncomingSound(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return;
    final hasForeignMessage = messages.any((msg) => !_config.isOwnMessage(msg));
    if (!hasForeignMessage) return;
    _playMessageSound(incoming: true);
  }

  void _playMessageSound({bool incoming = true}) {
    Future<void>(() async {
      try {
        _audioPlayer ??= AudioPlayer(playerId: 'shared_chat_sfx')
          ..setReleaseMode(ReleaseMode.stop);
        final bytes = incoming
            ? (_incomingToneBytes ??= _generateToneBytes(frequency: 880))
            : (_outgoingToneBytes ??=
                _generateToneBytes(frequency: 660, durationSeconds: 0.14));
        await _audioPlayer!.stop();
        await _audioPlayer!.play(BytesSource(bytes), volume: incoming ? 0.6 : 0.4);
      } catch (_) {
        try {
          SystemSound.play(incoming ? SystemSoundType.alert : SystemSoundType.click);
        } catch (_) {
          // best-effort fallback; ignore
        }
      }
    });
  }

  Uint8List _generateToneBytes({
    required double frequency,
    double durationSeconds = 0.2,
  }) {
    const sampleRate = 44100;
    final sampleCount = (sampleRate * durationSeconds).round();
    final amplitude = 0.32;
    final toneData = ByteData(sampleCount * 2);
    for (int i = 0; i < sampleCount; i++) {
      final value = (sin(2 * pi * frequency * i / sampleRate) * 32767 * amplitude)
          .round();
      toneData.setInt16(i * 2, value.clamp(-32768, 32767), Endian.little);
    }

    final dataSize = sampleCount * 2;
    final chunkSize = 36 + dataSize;

    final buffer = BytesBuilder();
    buffer.add(ascii.encode('RIFF'));
    buffer.add(_int32LE(chunkSize));
    buffer.add(ascii.encode('WAVE'));
    buffer.add(ascii.encode('fmt '));
    buffer.add(_int32LE(16));
    buffer.add(_int16LE(1));
    buffer.add(_int16LE(1));
    buffer.add(_int32LE(sampleRate));
    buffer.add(_int32LE(sampleRate * 2));
    buffer.add(_int16LE(2));
    buffer.add(_int16LE(16));
    buffer.add(ascii.encode('data'));
    buffer.add(_int32LE(dataSize));
    buffer.add(toneData.buffer.asUint8List());
    return buffer.toBytes();
  }

  Uint8List _int16LE(int value) {
    final data = ByteData(2);
    data.setInt16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _int32LE(int value) {
    final data = ByteData(4);
    data.setInt32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Future<void> _openLocalAttachment(String path, String fallbackUrl) async {
    try {
      if (!kIsWeb) {
        final file = File(path);
        if (!await file.exists()) {
          if (fallbackUrl.isNotEmpty) {
            _openRemoteWithoutDownload(fallbackUrl);
            return;
          }
          _showSnackBar('File is no longer on this device.');
          return;
        }
      }
      await file_downloader.openDownloadedFile(path, fallbackUrl: fallbackUrl);
    } catch (error) {
      _showSnackBar('Unable to open file: $error');
    }
  }

  Future<void> _openRemoteWithoutDownload(String url) async {
    try {
      await file_downloader.openDownloadedFile(url, fallbackUrl: url);
    } catch (error) {
      _showSnackBar('Unable to open file: $error');
    }
  }

  void _deleteMessageForMe(Map<String, dynamic> message) {
    final messageId = message['id'];
    final attachmentKey = messageId == null ? null : '${messageId}_attachment';

    if (attachmentKey != null) {
      _resetDownloadState(attachmentKey);
    }

    final msgKey = _messageId(message);
    if (msgKey > 0) {
      _localFileHints.remove(msgKey);
      _localFileNames.remove(msgKey);
    }

    setState(() {
      _messages.removeWhere((m) => m['id'] == messageId);
    });
    _notifyCountsFromMessages();
    _showSnackBar('Message deleted');
  }

  DateTime? _messageTimestamp(Map<String, dynamic> message) {
    final raw = message['date_sent'] ?? message['created_at'];
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    if (raw is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(raw * (raw < 10000000000 ? 1000 : 1));
      } catch (_) {
        return null;
      }
    }
    if (raw is DateTime) return raw;
    return null;
  }

  int _messageId(Map<String, dynamic> message) {
    final id = message['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  int _compareMessages(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aTime = _messageTimestamp(a);
    final bTime = _messageTimestamp(b);
    if (aTime != null && bTime != null) {
      final cmp = aTime.compareTo(bTime);
      if (cmp != 0) return cmp;
    }
    return _messageId(a).compareTo(_messageId(b));
  }

  int _resolveLastMessageId(int? preferred, List<Map<String, dynamic>> messages) {
    if (preferred != null && preferred > 0) return preferred;
    if (messages.isEmpty) return 0;
    return _messageId(messages.last);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _audioPlayer?.dispose();
    _pushSubscription?.cancel();
    _pollingTimer?.cancel();
    _notificationService.clearChatNotifications(_notificationKey);
    _notificationService.resetConversationTracking();
    super.dispose();
  }

  String get _notificationKey {
    if (_config.role == ChatRole.adminSupport) {
      final role = _participant?.role ?? 'participant';
      final id = _participant?.id ?? 'inbox';
      return 'support_${role}_$id';
    }
    if (_config.role == ChatRole.marketer) return 'marketer_chat';
    if (_config.role == ChatRole.client) return 'admin_chat';
    return _downloadNamespace;
  }

  Future<void> _initializeChatData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final initial = await _config.loadInitialMessages(
        token: _token,
        participant: _participant,
        lastMessageId: null,
      );

      final normalized = initial.messages
          .map<Map<String, dynamic>>(_config.normalizeBackendMessage)
          .toList();

      normalized.sort(_compareMessages);

      _participant = initial.participant ?? _participant;
      _lastMessageId = _resolveLastMessageId(
        initial.lastMessageId,
        normalized,
      );

      if (!mounted) return;
      setState(() {
        _messages = normalized;
        _isLoading = false;
      });

      _scrollToBottom(immediate: true);

      await Future.wait([
        _markMessagesAsRead(markAll: true),
        _loadCurrentUserAvatar(),
      ]);

      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _scrollToBottom();
      });
      _notifyCountsFromMessages();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentUserAvatar() async {
    if (_config.loadCurrentUserAvatar == null) return;
    try {
      final avatar = await _config.loadCurrentUserAvatar!(
        token: _token,
        participant: _participant,
      );
      if (!mounted) return;
      setState(() => _currentUserAvatar = avatar);
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentUserAvatar = null);
    }
  }

  Future<void> _loadCachedDownloads() async {
    final saved = await _downloadCache.readAll(_downloadNamespace);
    final completed = <String, bool>{};
    final paths = <String, String>{};

    for (final entry in saved.entries) {
      final path = entry.value;
      if (path.isEmpty) {
        await _downloadCache.removeEntry(_downloadNamespace, entry.key);
        continue;
      }

      if (!kIsWeb) {
        final file = File(path);
        if (!await file.exists()) {
          await _downloadCache.removeEntry(_downloadNamespace, entry.key);
          continue;
        }
      }

      completed[entry.key] = true;
      paths[entry.key] = path;
    }

    if (!mounted) return;
    setState(() {
      _downloadCompleted.addAll(completed);
      _downloadedFilePaths.addAll(paths);
    });
  }

  void _subscribeToPushMessages() {
    try {
      _pushSubscription = PushNotificationService()
          .incomingPushEvents
          .listen((payload) async {
        final data = payload['data'] as Map<String, dynamic>?;
        if (data == null || !mounted) return;

        if (_config.pushChannelMatcher(payload)) {
          await _pollForNewMessages();
        } else if (payload['type']?.toString().toLowerCase() ==
            'chat_message_deleted') {
          final deletedId = int.tryParse(data['message_id']?.toString() ?? '');
          if (deletedId == null) return;
          if (!mounted) return;
          setState(() {
            for (final message in _messages) {
              if (message['id'] == deletedId) {
                message['content'] = '🚫 This message was deleted';
                message['_deleted_for_everyone'] = true;
                message['file_url'] = null;
                message['file_type'] = null;
                message['file'] = null;
              }
            }
          });
        }
      });
    } catch (error) {
      debugPrint('SharedChatThreadPage push subscription failed: $error');
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isPolling && !_isLoading) {
        unawaited(_pollForNewMessages());
      }
    });
  }

  Future<void> _pollForNewMessages() async {
    if (_isPolling || _isLoading) return;
    _isPolling = true;

    try {
      final pollResult = await _config.pollForMessages(
        token: _token,
        participant: _participant,
        lastMessageId: _lastMessageId,
      );

      if (pollResult.newMessages.isEmpty) return;

      final normalized = pollResult.newMessages
          .map<Map<String, dynamic>>(_config.normalizeBackendMessage)
          .where((msg) => _isValidBackendMessage(msg))
          .toList();

      if (normalized.isEmpty) return;
      if (!mounted) return;

      final existingIds = _messages
          .map(_messageId)
          .where((id) => id > 0)
          .toSet();
      final List<Map<String, dynamic>> uniqueNewMessages = [];

      for (final message in normalized) {
        final msgId = _messageId(message);
        if (msgId <= 0) {
          uniqueNewMessages.add(message);
          continue;
        }
        if (existingIds.add(msgId)) {
          uniqueNewMessages.add(message);
        }
      }

      if (uniqueNewMessages.isEmpty) return;

      final bool userWasScrolledUp = _isUserScrolledUp;

      for (final message in uniqueNewMessages) {
        if (!_config.isOwnMessage(message) && message['is_read'] != false) {
          message['is_read'] = false;
        }
      }

      setState(() {
        _messages.addAll(uniqueNewMessages);
        _messages.sort(_compareMessages);
        _lastMessageId = _resolveLastMessageId(
          pollResult.lastMessageId,
          _messages,
        );
        if (userWasScrolledUp) {
          _pendingNewMessageCount += uniqueNewMessages.length;
        }
      });

      final bool hasForeignMessage =
          uniqueNewMessages.any((msg) => !_config.isOwnMessage(msg));
      if (hasForeignMessage) {
        _playMessageSound(incoming: true);
      }

      if (!userWasScrolledUp) {
        _scrollToBottom();
        await _markMessagesAsRead(markAll: true);
      }

      _notifyCountsFromMessages();
    } catch (error) {
      debugPrint('SharedChatThreadPage poll failed: $error');
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _markMessagesAsRead({bool markAll = false}) async {
    try {
      final ids = markAll ? null : _unreadIncomingMessageIds();
      if (!markAll && (ids == null || ids.isEmpty)) {
        return;
      }

      await _config.markMessagesAsRead(
        token: _token,
        messageIds: ids,
        participant: _participant,
      );

      if (!mounted) return;

      final Set<int>? idSet = ids?.toSet();
      bool updated = false;

      setState(() {
        for (final message in _messages) {
          if (_config.isOwnMessage(message)) continue;
          if (markAll || (idSet != null && idSet.contains(_messageId(message)))) {
            if (message['is_read'] != true) {
              message['is_read'] = true;
              updated = true;
            }
          }
        }
      });

      if (updated || markAll) {
        _notifyCountsFromMessages();
      }
    } catch (_) {
      // non-critical
    }
  }

  List<int> _unreadIncomingMessageIds() {
    return _messages
        .where((msg) => !_config.isOwnMessage(msg) && msg['is_read'] != true)
        .map((msg) => msg['id'])
        .whereType<int>()
        .toList();
  }

  Future<void> _sendCurrentMessage() async {
    if (_isSending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingFile == null) return;

    final localAttachmentPath = _pendingFile?.path;
    final localAttachmentName = _pendingFileName;
    setState(() => _isSending = true);

    try {
      final result = await _config.sendMessage(
        token: _token,
        participant: _participant,
        content: text.isNotEmpty ? text : null,
        messageType: null,
        replyToMessageId: null,
        attachment: _pendingFile,
      );

      final message = _config.normalizeBackendMessage(result.message);
      if (!mounted) return;

      setState(() {
        _messages.add(message);
        _messages.sort(_compareMessages);
        _lastMessageId = _resolveLastMessageId(
          result.lastMessageId ?? message['id'] as int?,
          _messages,
        );
        final messageKey = _messageId(message);
        if (localAttachmentPath != null && messageKey > 0) {
          _localFileHints[messageKey] = localAttachmentPath;
          final name = localAttachmentName?.trim().isNotEmpty == true
              ? localAttachmentName!.trim()
              : _extractFileNameFromPath(localAttachmentPath);
          if (name != null) {
            _localFileNames[messageKey] = name;
          }
        }
        _messageController.clear();
      });

      _playMessageSound(incoming: false);
      _clearPendingFile();
      _scrollToBottom();
      _notifyCountsFromMessages();
      await _markMessagesAsRead(markAll: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final messageId = message['id'] as int?;
    if (messageId == null) return;

    setState(() => message['_deleting'] = true);
    try {
      final updated = await _config.deleteMessage(
        token: _token,
        messageId: messageId,
        participant: _participant,
      );

      final normalized = _config.normalizeBackendMessage(updated);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index != -1) {
          _messages[index] = normalized;
        }
        final attachmentKey = '${messageId}_attachment';
        _resetDownloadState(attachmentKey);
        final msgKey = _messageId(normalized);
        if (msgKey > 0) {
          _localFileHints.remove(msgKey);
          _localFileNames.remove(msgKey);
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => message['_deleting'] = false);
      }
    }
  }

  void _scrollToBottom({bool immediate = false, int retries = 4}) {
    if (retries < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        if (retries == 0) return;
        Future.delayed(const Duration(milliseconds: 16), () {
          if (mounted) {
            _scrollToBottom(immediate: immediate, retries: retries - 1);
          }
        });
        return;
      }

      final position = _scrollController.position;
      final target = position.maxScrollExtent;

      if (immediate) {
        try {
          position.jumpTo(target);
        } catch (_) {
          // ignore jump errors and retry
        }
      } else {
        try {
          position.animateTo(
            target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        } catch (_) {
          // fall back to jump on failure
          position.jumpTo(target);
        }
      }

      Future.delayed(const Duration(milliseconds: 16), () {
        if (!mounted || !_scrollController.hasClients) return;

        final remaining =
            (position.maxScrollExtent - position.pixels).abs();
        if (remaining > 12 && retries > 0) {
          _scrollToBottom(immediate: true, retries: retries - 1);
          return;
        }

        if (_pendingNewMessageCount != 0 || _isUserScrolledUp) {
          _pendingNewMessageCount = 0;
          _isUserScrolledUp = false;
          if (mounted) setState(() {});
          unawaited(_markMessagesAsRead(markAll: true));
        }
      });
    });
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final atBottom = (maxScroll - current).abs() < 72.0;

    if (atBottom) {
      if (_isUserScrolledUp || _pendingNewMessageCount > 0) {
        _isUserScrolledUp = false;
        _pendingNewMessageCount = 0;
        setState(() {});
        unawaited(_markMessagesAsRead(markAll: true));
      }
    } else {
      if (!_isUserScrolledUp) {
        _isUserScrolledUp = true;
        setState(() {});
      }
    }
  }

  void _notifyCountsFromMessages() {
    if (!mounted) return;
    final controller = AppLayout.maybeOf(context);
    if (controller == null) return;

    final unreadCount = _messages
        .where((msg) => !_config.isOwnMessage(msg) && msg['is_read'] != true)
        .length;
    controller.updateCounts(messages: unreadCount);
  }

  bool _isValidBackendMessage(Map<String, dynamic> message) {
    return message.containsKey('id') && message.containsKey('date_sent');
  }

  bool _isFromCurrentUser(Map<String, dynamic> message) {
    return _config.isOwnMessage(message);
  }

  bool _isDeleteForEveryoneEligible(Map<String, dynamic> message) {
    final sentTime = _messageTimestamp(message);
    if (sentTime == null) return false;
    final now = DateTime.now();
    final age = now.difference(sentTime);
    return age.inMinutes < 1440; // 24 hours
  }

  String? _extractFileNameFromPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : null;
  }

  String _resolveMessageFileName(
    Map<String, dynamic> message,
    String? localPath,
  ) {
    final msgKey = _messageId(message);
    final localName = msgKey > 0 ? _localFileNames[msgKey] : null;
    if (localName?.isNotEmpty == true) return localName!;

    final provided = message['file_name']?.toString();
    if (provided != null && provided.trim().isNotEmpty) {
      return provided.trim();
    }

    final derived = _extractFileNameFromPath(localPath ?? message['file_url']?.toString());
    if (derived != null && derived.trim().isNotEmpty) {
      return derived.trim();
    }

    return 'Attachment';
  }

  Future<void> _setPendingFile(
    File file, {
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final fileStat = await file.stat();
    final derivedMime = mimeType ?? lookupMimeType(file.path) ?? 'application/octet-stream';
    final resolvedName = fileName ?? p.basename(file.path);
    setState(() {
      _pendingFile = file;
      _pendingFileName = resolvedName;
      _pendingFileType = derivedMime;
      _pendingFileSize = fileSize ?? fileStat.size;
    });
  }

  void _clearPendingFile() {
    setState(() {
      _pendingFile = null;
      _pendingFileName = null;
      _pendingFileType = null;
      _pendingFileSize = null;
    });
  }

  Future<void> _pickImageFromGallery() async {
    if (kIsWeb) {
      _showSnackBar('Image uploads from web are not yet supported.');
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    await _setPendingFile(File(picked.path));
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      _showSnackBar('Camera uploads from web are not yet supported.');
      return;
    }
    final picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return;
    await _setPendingFile(File(picked.path));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      withReadStream: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'txt',
        'rtf',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    try {
      File? file;
      if (picked.path != null) {
        file = File(picked.path!);
      } else {
        file = await _persistPlatformFile(picked);
      }
      await _setPendingFile(
        file,
        fileName: picked.name,
        fileSize: picked.size,
      );
    } catch (error) {
      _showSnackBar('Unable to access selected file.');
    }
  }

  Future<File> _persistPlatformFile(PlatformFile file) async {
    if (file.bytes != null) {
      final tempDir = await getTemporaryDirectory();
      final safeName = file.name.isNotEmpty
          ? file.name
          : 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final path = p.join(tempDir.path, safeName);
      final target = File(path);
      await target.writeAsBytes(file.bytes!, flush: true);
      return target;
    }

    if (file.readStream != null) {
      final tempDir = await getTemporaryDirectory();
      final safeName = file.name.isNotEmpty
          ? file.name
          : 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final path = p.join(tempDir.path, safeName);
      final target = File(path);
      final sink = target.openWrite();
      await file.readStream!.pipe(sink);
      await sink.close();
      return target;
    }

    if (file.path != null) {
      return File(file.path!);
    }

    throw Exception('No readable data for selected file.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = _config.headerBuilder(context, _participant);
    final EdgeInsets resolvedPadding =
        _config.bodyPaddingBuilder?.call(context) ?? const EdgeInsets.symmetric(horizontal: 8);
    final double topPadding = header == null ? resolvedPadding.top : 0;
    final double bottomPadding = resolvedPadding.bottom;

    final EdgeInsets listPadding = EdgeInsets.fromLTRB(
      resolvedPadding.left,
      topPadding,
      resolvedPadding.right,
      bottomPadding,
    );

    final content = Stack(
      children: [
        Padding(
          padding: listPadding,
          child: _buildMessagesList(theme),
        ),
        if (_isLoading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_errorMessage != null)
          Positioned.fill(
            child: Center(
              child: Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_isUserScrolledUp && _pendingNewMessageCount > 0)
          Positioned(
            bottom: 80,
            right: 16,
            child: GestureDetector(
              onTap: () => _scrollToBottom(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_downward_rounded, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _pendingNewMessageCount == 1
                          ? '1 new message'
                          : '$_pendingNewMessageCount new messages',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: header,
      body: SafeArea(
        top: header == null,
        bottom: false,
        child: Column(
          children: [
            Expanded(child: content),
            if (_pendingFile != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: _buildAttachmentPreview(theme)),
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: max(MediaQuery.of(context).padding.bottom, 8),
                top: 8,
              ),
              child: _buildComposer(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with a friendly message.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isFromMe = _isFromCurrentUser(message);
    final hasFile = message['file_url'] != null &&
        message['file_url'].toString().isNotEmpty;
    final content = message['content']?.toString() ?? '';
    final rawContent = message['raw_content']?.toString();
    final displayText = content.isNotEmpty
        ? content
        : (rawContent?.isNotEmpty == true
            ? rawContent!
            : message['body']?.toString() ?? '');

    final profileImageUrl = _config.messageAvatarBuilder(
      message,
      _currentUserAvatar,
    );

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final avatarSize = isSmallScreen ? 32.0 : 36.0;
    final bubbleMaxWidth = screenWidth * (isSmallScreen ? 0.82 : 0.75);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildProfileAvatar(
                profileImageUrl: profileImageUrl,
                size: avatarSize,
                heroTag: 'chat_avatar_${message['id']}',
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: bubbleMaxWidth,
                minWidth: 60,
              ),
              child: GestureDetector(
                onLongPress: isFromMe && message['_deleted_for_everyone'] != true
                    ? () => _showMessageOptions(message)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutQuad,
                  padding: EdgeInsets.symmetric(
                    horizontal: hasFile ? 10 : 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isFromMe
                        ? const Color(0xFF128C7E)
                        : const Color(0xFFEFF1F5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          Radius.circular(isFromMe ? 16 : isSmallScreen ? 8 : 4),
                      bottomRight:
                          Radius.circular(!isFromMe ? 16 : isSmallScreen ? 8 : 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasFile)
                        _buildAttachmentPreviewTile(message, isFromMe),
                      if (displayText.isNotEmpty)
                        Text(
                          displayText,
                          style: TextStyle(
                            color: isFromMe
                                ? Colors.white
                                : const Color(0xFF303030),
                            fontSize: 14,
                            height: 1.4,
                            fontWeight:
                                message['_deleted_for_everyone'] == true
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimestamp(message['date_sent']),
                              style: TextStyle(
                                fontSize: 11,
                                color: isFromMe
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                            if (isFromMe)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Icon(
                                  message['is_read'] == true
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 16,
                                  color: message['is_read'] == true
                                      ? Colors.lightBlueAccent
                                      : Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isFromMe)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildProfileAvatar(
                profileImageUrl: profileImageUrl,
                size: avatarSize,
                heroTag: 'chat_avatar_me_${message['id']}',
                isOwn: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreviewTile(
      Map<String, dynamic> message, bool isFromMe) {
    final fileUrl = message['file_url']?.toString();
    final fileName = message['file_name']?.toString() ?? 'Attachment';
    final fileType = message['file_type']?.toString() ?? 'file';
    final fileId = '${message['id']}_attachment';
    final messageKey = _messageId(message);
    final localPath = messageKey > 0 ? _localFileHints[messageKey] : null;
    final completed = isFromMe || _downloadCompleted[fileId] == true;
    final progress = _downloadProgress[fileId] ?? 0.0;
    final displayName = _resolveMessageFileName(message, localPath);
    final isImage = fileType.startsWith('image');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (fileUrl == null && localPath == null) {
          _showSnackBar('Attachment unavailable');
          return;
        }
        _handleFileTap(
          fileId,
          fileUrl ?? '',
          displayName,
          isFromMe: isFromMe,
          localHint: localPath,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isFromMe ? Colors.white.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isImage && (localPath != null || (fileUrl?.isNotEmpty ?? false)))
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildAttachmentThumbnail(localPath, fileUrl, isFromMe),
                ),
              )
            else ...[
              _buildAttachmentIcon(fileType, isFromMe),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      color: isFromMe ? Colors.white : const Color(0xFF303030),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (!isFromMe && _downloadProgress.containsKey(fileId) && !completed)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isFromMe
                            ? Colors.white10
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFromMe
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    isFromMe
                        ? 'Open from device'
                        : completed
                            ? 'Open file'
                            : _downloadProgress.containsKey(fileId)
                                ? 'Downloading…'
                                : 'Tap to download',
                    style: TextStyle(
                      color: isFromMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                completed ? Icons.open_in_new_rounded : Icons.download_rounded,
                color: isFromMe ? Colors.white : Theme.of(context).primaryColor,
              ),
              onPressed: () {
                if (fileUrl == null && localPath == null) {
                  _showSnackBar('Attachment unavailable');
                  return;
                }
                _handleFileTap(
                  fileId,
                  fileUrl ?? '',
                  displayName,
                  isFromMe: isFromMe,
                  localHint: localPath,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentThumbnail(String? localPath, String? remoteUrl, bool isFromMe) {
    if (localPath != null) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
        );
      }
    }

    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        width: 70,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAttachmentIcon('image', isFromMe),
      );
    }

    return _buildAttachmentIcon('image', isFromMe);
  }

  Widget _buildAttachmentIcon(String fileType, bool isFromMe) {
    Color color = isFromMe ? Colors.white : const Color(0xFF128C7E);
    IconData icon = Icons.insert_drive_file_rounded;
    if (fileType.startsWith('image')) icon = Icons.image_rounded;
    if (fileType.startsWith('video')) icon = Icons.play_circle_fill_rounded;
    if (fileType.contains('pdf')) icon = Icons.picture_as_pdf_rounded;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFromMe ? Colors.white10 : const Color(0xFF128C7E).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildProfileAvatar({
    required String? profileImageUrl,
    required double size,
    required String heroTag,
    bool isOwn = false,
  }) {
    final borderColor = isOwn ? const Color(0xFF128C7E) : Colors.grey.shade300;
    ImageProvider? imageProvider;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      if (profileImageUrl.startsWith('asset://')) {
        imageProvider = AssetImage(profileImageUrl.substring('asset://'.length));
      } else {
        imageProvider = NetworkImage(profileImageUrl);
      }
    }
    return Hero(
      tag: heroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: ClipOval(
          child: imageProvider != null
              ? Image(
                  image: imageProvider!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildFallbackAvatar(isOwn: isOwn);
                  },
                )
              : _buildFallbackAvatar(isOwn: isOwn),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar({bool isOwn = false}) {
    return Container(
      color: isOwn ? const Color(0xFF128C7E) : Colors.grey.shade200,
      child: Icon(
        Icons.person,
        color: isOwn ? Colors.white : Colors.grey.shade500,
      ),
    );
  }

  Widget _buildAttachmentPreview(ThemeData theme) {
    if (_pendingFile == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingFileName ?? 'Attachment',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pendingFileType ?? 'Unknown type',
                  style: theme.textTheme.bodySmall,
                ),
                if (_pendingFileType?.startsWith('image') == true && _pendingFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _pendingFile!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _clearPendingFile,
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(ThemeData theme) {
    final canSend = _messageController.text.trim().isNotEmpty || _pendingFile != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildAttachmentButton(theme),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: canSend ? _sendCurrentMessage : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend
                      ? theme.colorScheme.primary
                      : Colors.grey.shade300,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: canSend ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton(ThemeData theme) {
    return IconButton(
      icon: Icon(Icons.attach_file_rounded, color: theme.colorScheme.primary),
      onPressed: _showAttachmentOptions,
      tooltip: 'Attach',
    );
  }

  Future<void> _showAttachmentOptions() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Photo library'),
                onTap: () async {
                  await _pickImageFromGallery();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Take photo'),
                onTap: () async {
                  await _takePhoto();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: const Text('Document (PDF, DOC, PPT, XLS, TXT)'),
                onTap: () async {
                  await _pickDocument();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    if (!_config.isOwnMessage(message)) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final supportsDeleteForEveryone = true;
        final deleteForEveryoneEligible = _isDeleteForEveryoneEligible(message);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for me'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(message);
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: const Text('Delete for everyone'),
                subtitle: deleteForEveryoneEligible
                    ? null
                    : const Text('Available within 24 hours'),
                enabled: supportsDeleteForEveryone && deleteForEveryoneEligible,
                onTap: !(supportsDeleteForEveryone && deleteForEveryoneEligible)
                    ? null
                    : () {
                        Navigator.pop(context);
                        _deleteMessage(message);
                      },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final DateTime dateTime = timestamp is DateTime
          ? timestamp
          : DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays >= 1) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours >= 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes >= 1) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Now';
      }
    } catch (_) {
      return timestamp.toString();
    }
  }

  void _handleFileTap(
    String fileId,
    String fileUrl,
    String fileName, {
    required bool isFromMe,
    String? localHint,
  }) {
    if (isFromMe) {
      if (localHint != null) {
        _openLocalAttachment(localHint, fileUrl);
        return;
      }
      if (fileUrl.isNotEmpty) {
        _openRemoteWithoutDownload(fileUrl);
        return;
      }
      _showSnackBar('File is no longer available.');
      return;
    }

    if (_downloadCompleted[fileId] == true) {
      _openDownloadedAttachment(fileId, fileName, fileUrl);
      return;
    }

    final currentProgress = _downloadProgress[fileId];
    if (currentProgress != null && currentProgress < 1.0) {
      return; // already downloading
    }

    _startInlineDownload(fileId, fileUrl, fileName);
  }

  Future<void> _startInlineDownload(
    String fileId,
    String fileUrl,
    String fileName, {
    bool forceRefresh = false,
  }) async {
    setState(() {
      _downloadProgress[fileId] = 0.0;
      _downloadCompleted[fileId] = false;
      _downloadCancelFlags[fileId] = false;
      if (forceRefresh) {
        _downloadedFilePaths.remove(fileId);
        _downloadCache.removeEntry(_downloadNamespace, fileId);
      }
    });

    final notificationId =
        await _notificationService.showDownloadNotification(fileName);
    if (notificationId != null) {
      _downloadNotificationIds[fileId] = notificationId;
    }

    try {
      final path = await file_downloader.downloadFileWithProgress(
        filename: fileName,
        url: fileUrl,
        onProgress: (received, total) {
          if (!mounted || total == 0) return;
          setState(() {
            _downloadProgress[fileId] = received / total;
          });
          if (notificationId != null) {
            _notificationService.updateDownloadNotification(
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
        _resetDownloadState(fileId, notify: true, message: 'Download cancelled');
        return;
      }

      setState(() {
        _downloadProgress[fileId] = 1.0;
        _downloadCompleted[fileId] = true;
        _downloadedFilePaths[fileId] = path;
        _downloadCancelFlags.remove(fileId);
      });
      await _downloadCache.saveEntry(_downloadNamespace, fileId, path);
      _showSnackBar('Saved $fileName');
      if (notificationId != null) {
        await _notificationService.completeDownloadNotification(
          notificationId: notificationId,
          fileName: fileName,
          filePath: path,
          fileUrl: fileUrl,
        );
        _downloadNotificationIds.remove(fileId);
      }
    } catch (error) {
      if (!mounted) return;
      _resetDownloadState(fileId, notify: true, message: 'Failed to download: $error');
      final id = notificationId ?? _downloadNotificationIds.remove(fileId);
      if (id != null) {
        await _notificationService.failDownloadNotification(
          notificationId: id,
          fileName: fileName,
          reason: error.toString(),
        );
      }
      await _downloadCache.removeEntry(_downloadNamespace, fileId);
    }
  }

  void _resetDownloadState(String fileId,
      {bool notify = false, String? message}) {
    setState(() {
      _downloadProgress.remove(fileId);
      _downloadCompleted.remove(fileId);
      _downloadCancelFlags.remove(fileId);
      _downloadedFilePaths.remove(fileId);
    });
    final id = _downloadNotificationIds.remove(fileId);
    if (id != null) {
      _notificationService.cancelDownloadNotification(id);
    }
    if (notify && message != null) {
      _showSnackBar(message);
    }
  }

  Future<void> _openDownloadedAttachment(
      String fileId, String fileName, String fileUrl) async {
    final path = _downloadedFilePaths[fileId];
    if (path == null || path.isEmpty) {
      if (fileUrl.isNotEmpty) {
        _startInlineDownload(fileId, fileUrl, fileName, forceRefresh: true);
      } else {
        _showSnackBar('File is no longer available.');
      }
      return;
    }

    if (!kIsWeb) {
      final file = File(path);
      if (!await file.exists()) {
        await _downloadCache.removeEntry(_downloadNamespace, fileId);
        _resetDownloadState(fileId);
        if (fileUrl.isNotEmpty) {
          _startInlineDownload(fileId, fileUrl, fileName, forceRefresh: true);
        }
        return;
      }
    }

    try {
      await file_downloader.openDownloadedFile(path, fallbackUrl: fileUrl);
    } catch (error) {
      _showSnackBar('Unable to open file: $error');
    }
  }
}
