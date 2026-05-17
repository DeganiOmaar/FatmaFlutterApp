import 'package:flutter/foundation.dart';
import 'package:pfe/config/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class ChatService {
  late io.Socket socket;

  void connect(String userId, Function(dynamic) onMessage) {
    socket = io.io(ApiConfig.socketUrl, {
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      debugPrint("✅ Connected");
      socket.emit('join', userId);
    });

    socket.on('receive_message', (data) {
      debugPrint("📩 Nouveau message : ${data['text']}");
      onMessage(data); // 🔥 update UI
    });
  }
  void sendMessage(String senderId, String receiverId, String content,String projectId) {
   socket.emit('send_message', {
  'senderId': senderId,
  'receiverId': receiverId,
  'text': content,
  'projectId': projectId,
});
  }
   void disconnect() {
    socket.disconnect();
  }
}