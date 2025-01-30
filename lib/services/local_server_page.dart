import 'package:flutter/material.dart';
import 'local_server_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

class LocalServerPage extends StatefulWidget {
  @override
  _LocalServerPageState createState() => _LocalServerPageState();
}

class _LocalServerPageState extends State<LocalServerPage> with WidgetsBindingObserver {
  // サーバー状態を格納する変数
  String _statusMessage = "サーバーが停止しています";

  // IPアドレスを格納する変数
  String _localIpAddress = "IPアドレスを取得中...";

  // QRコード用のデータ
  String _qrData = "";

  // サーバー管理用オブジェクト
  late LocalServerManager serverManager;

  @override
  void initState() {
    super.initState();
    // ProviderからLocalServerManagerのインスタンスを取得
    serverManager = Provider.of<LocalServerManager>(context, listen: false);
    //ネットワークの監視をスタートする
    Future.microtask(() => serverManager.startNetworkMonitor());
    // IPアドレスを取得
    _fetchLocalIpAddress();
    // サーバー状態を更新
    _updateServerStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Providerから再度LocalServerManagerのインスタンスを取得
    serverManager = Provider.of<LocalServerManager>(context);
    // サーバー状態を更新
    _updateServerStatus();
  }

  @override
  void dispose() {
    // ウィジェットが破棄されるときに、監視を停止
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // IPアドレスを取得して画面に反映
  Future<void> _fetchLocalIpAddress() async {
    // IPアドレスを取得
    final ipAddress = await serverManager.getLocalIpAddress();
    setState(() {
      // 取得したIPアドレスを画面に反映
      _localIpAddress = ipAddress;
      // QRコード用データを生成
      _generateQrData(ipAddress);
    });
    // アプリの状態にIPアドレスを設定
    Provider.of<AppState>(context, listen: false)
        .setServerConnectionDetails(_localIpAddress);
  }

  // サーバー状態を更新
  void _updateServerStatus() {
    setState(() {
      if (serverManager.isRunning && serverManager.getIpAddress) {
        // サーバーが動作中の場合
        // _statusMessage = "サーバーが起動しています: ポート ${serverManager.serverPort}";
        _statusMessage = "サーバーが起動しています";
      }
      else if(!serverManager.getIpAddress) {
        _qrData = "";
        _statusMessage = "IPアドレスを取得できません。サーバーが停止しています。";
      }
      else {
        _qrData = "";
       _statusMessage = "サーバーが停止しています";
      }
    });
  }

  // サーバーを起動するメソッド
  Future<void> _startServer() async {
    // サーバーを起動
    await serverManager.startServer();
    // サーバー状態を更新
    _updateServerStatus();
    // IPアドレスを取得
    _fetchLocalIpAddress();
    // // サーバー起動後にQRコードを更新
    // _generateQrData(_localIpAddress);
  }

  // サーバーを停止
  Future<void> _stopServer() async {
    // サーバーを停止
    await serverManager.stopServer();
    // サーバー状態を更新
    _updateServerStatus();
    // サーバー停止時はQRコードを非表示にする
    setState(() {
      // サーバー停止時にはQRコードを非表示にする
      _qrData = "";
    });
  }

  // QRコード用データを生成
  void _generateQrData(String ipAddress) {
    if (serverManager.isRunning && ipAddress.isNotEmpty) {
      setState(() {
        // IPアドレスとポート番号をQRコード用データとして設定
        _qrData = "$ipAddress:${serverManager.serverPort}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ローカルサーバー設定")),
      body: Center(
        child: Consumer<LocalServerManager>(
          builder: (context, serverManager, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 30),
                // サーバーを起動するボタン
                ElevatedButton(
                  onPressed: _startServer,
                  child: Text(" ローカルサーバー起動 "),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: serverManager.isRunning ? Colors.grey : Colors.white,
                  ),
                ),
                SizedBox(height: 30),
                // サーバーを停止するボタン
                ElevatedButton(
                  onPressed: _stopServer,
                  child: Text(" ローカルサーバー停止 "),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !serverManager.isRunning ? Colors.grey : Colors.white,
                  ),
                ),
                SizedBox(height: 30),
                // QRコードの表示
                if (_qrData.isNotEmpty) ...[
                  Text(
                    "QRコードをスキャンして接続",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  QrImageView(
                    // QRコードに表示するデータ
                    data: _qrData,
                    // QRコードのバージョン
                    version: QrVersions.auto,
                    // QRコードのサイズ
                    size: 200.0,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "サーバー情報: $_qrData",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ],
            );
          }
      ),
    ),
  );
}
}
