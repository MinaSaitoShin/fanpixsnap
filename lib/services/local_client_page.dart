import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'local_socket_manager.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';


class LocalClientPage extends StatefulWidget {
  final Function(String) onConnected;

  LocalClientPage({required this.onConnected});

  @override
  _LocalClientPageState createState() => _LocalClientPageState();
}

class _LocalClientPageState extends State<LocalClientPage>
    with WidgetsBindingObserver {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  String _statusMessage = "未接続";
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR'); // QRスキャナー用のキー
  QRViewController? _qrController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // アプリ状態の監視を開始
    _updateConnectionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 監視を停止
    _qrController?.dispose(); // QRコントローラの解放
    super.dispose();
  }

  // アプリのライフサイクルが変化したときに呼ばれる
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _disconnectFromServer();
    }
  }

  // 接続状態を更新
  void _updateConnectionStatus() {
    setState(() {
      _statusMessage = localSocketManager.isConnected ? "接続済み" : "未接続";
    });
  }

  // サーバーに接続
  Future<void> _connectToServer() async {
    final ipAddress = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (ipAddress.isEmpty || port == null) {
      setState(() {
        _statusMessage = "IPアドレスまたはポート番号が無効です";
      });
      return;
    }

    await localSocketManager.connect(ipAddress, port);

    if (localSocketManager.isConnected) {
      setState(() {
        _statusMessage = "接続成功！ サーバー: $ipAddress:$port";
        widget.onConnected(ipAddress);
      });
      Provider.of<AppState>(context, listen: false)
          .setClientConnectionDetails(ipAddress, port);
    } else {
      setState(() {
        _statusMessage = "接続に失敗しました";
      });
    }
  }

  // 接続を切断
  Future<void> _disconnectFromServer() async {
    await localSocketManager.disconnect();
    _updateConnectionStatus();
  }

  // QRコードスキャン画面を開く
  Future<void> _scanQrCode() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('QRコードスキャン')),
          body: QRView(
            key: _qrKey,
            onQRViewCreated: (QRViewController controller) {
              _qrController = controller;
              controller.scannedDataStream.listen((scanData) {
                final data = scanData.code;

                // QRコードからIPアドレスとポートを分解
                if (data != null) {
                  final parts = data.split(':');
                  if (parts.length == 2) {
                    setState(() {
                      _ipController.text = parts[0].trim(); // IPアドレス
                      _portController.text = parts[1].trim(); // ポート番号
                    });
                    Future.delayed(Duration(milliseconds: 300),() {
                      _connectToServer();
                    });
                    Navigator.pop(context); // スキャン成功後に戻る
                  }
                }
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Client Page")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: "サーバーIPアドレス",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: "ポート番号",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _connectToServer,
              child: Text("接続"),
            ),
            ElevatedButton(
              onPressed: _disconnectFromServer,
              child: Text("切断"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _scanQrCode,
              child: Text("QRコードで接続情報をスキャン"),
            ),
            SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
