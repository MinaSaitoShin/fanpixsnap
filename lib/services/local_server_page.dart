import 'package:flutter/material.dart';
import 'local_server_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class LocalServerPage extends StatefulWidget {
  @override
  _LocalServerPageState createState() => _LocalServerPageState();
}

class _LocalServerPageState extends State<LocalServerPage> {
  String _statusMessage = "サーバーが停止しています";
  String _localIpAddress = "IPアドレスを取得中...";
  String _qrData = "";
  final serverManager = LocalServerManager();

  @override
  void initState() {
    super.initState();
    _fetchLocalIpAddress();
    _updateServerStatus();
  }

  // IPアドレスを取得して画面に反映
  Future<void> _fetchLocalIpAddress() async {
    final ipAddress = await serverManager.getLocalIpAddress();
    setState(() {
      _localIpAddress = ipAddress;
      _generateQrData(ipAddress); // QRコード用データ生成
    });
    Provider.of<AppState>(context, listen: false)
        .setServerConnectionDetails(_localIpAddress);

  }

  // サーバー状態を更新
  void _updateServerStatus() {
    setState(() {
      if (serverManager.isRunning) {
        _statusMessage =
        "サーバーが起動しています: ポート ${serverManager.serverPort}";
      } else {
        _statusMessage = "サーバーが停止しています";
      }
    });
  }

  // サーバーを起動
  Future<void> _startServer() async {
    await serverManager.startServer();
    _updateServerStatus();
    _generateQrData(_localIpAddress); // サーバー起動後にQRコードを更新
  }

  // サーバーを停止
  Future<void> _stopServer() async {
    await serverManager.stopServer();
    _updateServerStatus();
    setState(() {
      _qrData = ""; // サーバー停止時はQRコードを非表示にする
    });
  }

  // QRコード用データを生成
  void _generateQrData(String ipAddress) {
    if (serverManager.isRunning && ipAddress.isNotEmpty) {
      setState(() {
        _qrData = "$ipAddress:${serverManager.serverPort}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Local Server Page")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "ローカルIPアドレス: $_localIpAddress",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),

            // QRコードの表示
            if (_qrData.isNotEmpty) ...[
              Text(
                "QRコードをスキャンして接続",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              QrImageView(
                data: _qrData, // QRコードのデータ
                version: QrVersions.auto,
                size: 200.0, // QRコードのサイズ
              ),
              SizedBox(height: 20),
              Text(
                "サーバー情報: $_qrData",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],

            ElevatedButton(
              onPressed: _startServer,
              child: Text("サーバーを起動"),
            ),
            ElevatedButton(
              onPressed: _stopServer,
              child: Text("サーバーを停止"),
            ),
          ],
        ),
      ),
    );
  }
}
