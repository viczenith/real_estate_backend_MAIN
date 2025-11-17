import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(AdminChat());
}

class AdminChat extends StatelessWidget {
  const AdminChat({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/admin-chat',
      routes: {
        '/admin-chat': (context) => AdminChatScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  _AdminChatScreenState createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Chat background image file (user-selected)
  File? _chatBackground;

  /// Allow users to change the chat background.
  Future<void> _changeChatBackground() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _chatBackground = File(pickedFile.path);
      });
    }
  }

  void _sendMessage({String? text, File? file, String? fileType}) {
    if ((text == null || text.trim().isEmpty) && file == null) return;
    setState(() {
      _messages.add({
        "text": text,
        "file": file,
        "fileType": fileType,
        "isMe": true,
        "time": DateFormat('hh:mm a').format(DateTime.now()),
      });
      _isTyping = false;
    });
    _messageController.clear();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String extension = result.files.single.extension ?? "";
      String fileType = "file";
      if (["jpg", "jpeg", "png"].contains(extension)) fileType = "image";
      if (["mp4", "mov", "avi"].contains(extension)) fileType = "video";
      if (["mp3", "wav", "m4a"].contains(extension)) fileType = "audio";
      if (["pdf", "doc", "docx"].contains(extension)) fileType = "document";
      _sendMessage(file: file, fileType: fileType);
    }
  }

  Future<void> _recordVoiceNote() async {
    // Dummy voice note: Replace with actual recording logic.
    File fakeAudioFile = File('assets/sample_audio.mp3');
    _sendMessage(file: fakeAudioFile, fileType: "audio");
  }

  /// Build the chat header with a customizable background button.
  AppBar _buildChatHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      title: Row(
        children: [
          CircleAvatar(
              backgroundImage: AssetImage('assets/logo.png')),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Admin",
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              Text("Online",
                  style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        ],
      ),
      iconTheme: IconThemeData(color: Colors.black),
      actions: [
        // Button to change chat background.
        IconButton(
          icon: Icon(Icons.wallpaper, color: Colors.blueAccent),
          onPressed: _changeChatBackground,
        ),
        IconButton(
          icon: Icon(Icons.video_call, color: Colors.blueAccent),
          onPressed: () {
            // Integrate video call functionality.
          },
        ),
        IconButton(
          icon: Icon(Icons.call, color: Colors.blueAccent),
          onPressed: () {
            // Dummy audio call: show a dialog.
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("Audio Call"),
                content: Text("Dummy audio call initiated."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("OK"),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build the chat messages body.
  Widget _buildChatBody() {
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        return _buildMessageBubble(
          text: message['text'],
          file: message['file'],
          fileType: message['fileType'],
          isMe: message['isMe'],
          time: message['time'],
        );
      },
    );
  }

  /// Build an individual message bubble with file previews.
  Widget _buildMessageBubble({
    String? text,
    File? file,
    String? fileType,
    required bool isMe,
    required String time,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.all(10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (file != null && fileType == "image")
              Image.file(file, width: 200),
            if (file != null && fileType == "video")
              VideoPlayerWidget(videoFile: file),
            if (file != null && fileType == "audio")
              AudioPlayerWidget(audioFile: file, audioPlayer: _audioPlayer),
            if (file != null && fileType == "document")
              Text("📄 ${file.path.split('/').last}",
                  style: TextStyle(
                      color: isMe ? Colors.white : Colors.black)),
            if (text != null)
              Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : Colors.black),
              ),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the message input bar.
  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)]),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions, color: Colors.blueAccent),
            onPressed: () {
              // Open emoji picker here.
            },
          ),
          IconButton(
            icon: Icon(Icons.attach_file, color: Colors.blueAccent),
            onPressed: _pickFile,
          ),
          IconButton(
            icon: Icon(Icons.mic, color: Colors.redAccent),
            onPressed: _recordVoiceNote,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                  hintText: "Type a message...", border: InputBorder.none),
              onChanged: (text) =>
                  setState(() => _isTyping = text.trim().isNotEmpty),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send,
                color: _isTyping ? Colors.blueAccent : Colors.grey),
            onPressed: _isTyping
                ? () => _sendMessage(text: _messageController.text)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set a transparent background so the custom chat background shows.
      backgroundColor: Colors.transparent,
      appBar: _buildChatHeader(),
      body: Stack(
        children: [
          // Chat background: user-selected or default.
          Positioned.fill(
            child: _chatBackground != null
                ? Image.file(_chatBackground!, fit: BoxFit.cover)
                : Container(color: Color(0xFFF7F7F7)),
          ),
          // Chat messages and input.
          Column(
            children: [
              Expanded(child: _buildChatBody()),
              _buildMessageInput(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Video Player Widget for displaying video files.
class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;
  const VideoPlayerWidget({super.key, required this.videoFile});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : CircularProgressIndicator();
  }
}

/// Audio Player Widget for playing audio files.
class AudioPlayerWidget extends StatelessWidget {
  final File audioFile;
  final AudioPlayer audioPlayer;
  const AudioPlayerWidget({super.key, required this.audioFile, required this.audioPlayer});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.play_arrow, color: Colors.blueAccent),
      onPressed: () {
        audioPlayer.play(DeviceFileSource(audioFile.path));
      },
    );
  }
}
