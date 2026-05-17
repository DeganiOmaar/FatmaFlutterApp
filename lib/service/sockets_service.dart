import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pfe/config/api_config.dart';

class SocketService {
  late io.Socket socket;

  void connect(String userId) {
    socket = io.io(
      ApiConfig.origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      debugPrint("✅ Socket connecté");
      socket.emit("join", userId); // مهم
    });

    socket.on("notification", (data) {
      debugPrint("🔔 Notification: $data");

      Get.snackbar(
        data["title"] ?? "Notification",
        data["message"] ?? "",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.black,
        colorText: Colors.white,
      );
    });

    socket.onDisconnect((_) {
      debugPrint("❌ Socket disconnected");
    });
  }
}