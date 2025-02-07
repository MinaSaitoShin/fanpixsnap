import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/camera_screen.dart';
import '../screens/err_send_screen.dart';
import '../services/local_server_manager.dart';
import '../services/local_client_manager.dart';

// ログ画面を表示するウィジェット
class LogScreen extends StatelessWidget {
  // ログの最大表示数
  final int maxLogCount = 100;

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

          // ログ数が最大数を超えていたら制限する
          final limitedServerLogs = serverManager.logs.take(maxLogCount).toList();
          final limitedCombinedLogs = combinedLogs.take(maxLogCount).toList();

          return Column(
            children: [
              // サーバーのログを表示（最大数を制限）
              Expanded(
                child: ListView.builder(
                  itemCount: limitedServerLogs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: SelectableText("Server: ${limitedServerLogs[index]}"),
                    );
                  },
                ),
              ),
              Divider(),
              SizedBox(height: 20),
              // クライアントとカメラのログを統合して表示（最大数を制限）
              Expanded(
                child: ListView.builder(
                  itemCount: limitedCombinedLogs.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: SelectableText(limitedCombinedLogs[index]),
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
