import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/camera_screen.dart';
import '../screens/err_send_screen.dart';
import '../services/local_server_manager.dart';
import '../services/local_client_manager.dart';

// ログ画面を表示するウィジェット
class LogScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ログ画面")),
      body: Consumer4<LocalServerManager, LocalClientManager, CameraScreenState, ErrSendScreenState>(
        builder: (context, serverManager, clientManager, cameraState, errState, child) {
          // LocalClientManagerとCameraScreenStateのログは結合
          final combinedLogs = [
            ...clientManager.logs.map((log) => "Client: $log"),
            ...cameraState.logs.map((log) => "Camera: $log"),
            ...errState.logs.map((log) => "ErrSend: $log"),
          ];

          return Column(
            children: [
              // サーバーのログを表示
              Expanded(
                child: ListView.builder(
                  itemCount: serverManager.logs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text("Server: ${serverManager.logs[index]}"),
                    );
                  },
                ),
              ),
              Divider(),
              SizedBox(height: 20),
              // クライアントとカメラのログを統合して表示
              Expanded(
                child: ListView.builder(
                  itemCount: combinedLogs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(combinedLogs[index]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
