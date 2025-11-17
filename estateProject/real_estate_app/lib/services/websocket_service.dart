import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  void connect(String url) {
    disconnect();
    _channel = WebSocketChannel.connect(Uri.parse(url));
  }

  void sendMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
    }
  }

  Stream<dynamic> get messages {
    if (_channel != null) {
      return _channel!.stream;
    }
    return const Stream.empty();
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
  }
}
