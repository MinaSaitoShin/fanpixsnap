import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'local_client_manager.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';

// ユーザーがローカルサーバーに接続するためのUI
class LocalClientPage extends StatefulWidget {
  // 接続成功後に呼び出されるコールバック
  final Function(String) onConnected;

  // コンストラクタで接続成功後のコールバックを受け取る
  LocalClientPage({required this.onConnected});

  @override
  _LocalClientPageState createState() => _LocalClientPageState();
}

class _LocalClientPageState extends State<LocalClientPage>
    with WidgetsBindingObserver {
  // IPアドレスとポート番号の入力用コントローラ
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  // 接続状態を表示するためのメッセージ
  String _statusMessage = "未接続";
  // QRコードスキャナー用のキー
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  // QRコントローラ
  QRViewController? _qrController;

  @override
  void initState() {
    super.initState();
    // アプリの状態を監視するためのオブザーバー
    WidgetsBinding.instance.addObserver(this);
    _updateConnectionStatus();
  }

  @override
  void dispose() {
    // 状態監視を解除し、QRコントローラを解放
    WidgetsBinding.instance.removeObserver(this);
    _qrController?.dispose();
    super.dispose();
  }

  // アプリのライフサイクルが変化したときに呼ばれる
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリが非アクティブまたは切断された場合に接続を切断
    if (state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _disconnectFromServer();
    }
  }

  // 接続状態を更新
  void _updateConnectionStatus() {
    setState(() {
      // 接続されている場合は「接続済み」、そうでなければ「未接続」と表示
      _statusMessage = localClientManager.isConnected ? "接続済み" : "未接続";
    });
  }

  // サーバーに接続
  Future<void> _connectToServer() async {
    // 入力されたIPアドレス
    final ipAddress = _ipController.text.trim();
    // 入力されたポート番号
    final port = int.tryParse(_portController.text.trim());

    // IPアドレスまたはポート番号が無効な場合、接続を試みない
    if (ipAddress.isEmpty || port == null) {
      setState(() {
        _statusMessage = "IPアドレスまたはポート番号が無効です";
      });
      return;
    }

    // サーバーへの接続を試みる
    await localClientManager.connect(ipAddress, port);

    // 接続成功なら接続状態を更新し、コールバックを呼び出す
    if (localClientManager.isConnected) {
      setState(() {
        _statusMessage = "接続成功！ サーバー: $ipAddress:$port";
        // 接続後、外部から渡されたコールバックを呼び出す
        widget.onConnected(ipAddress);
      });
      // 接続情報をAppStateに保存
      Provider.of<AppState>(context, listen: false)
          .setClientConnectionDetails(ipAddress, port);
    } else {
      // 接続失敗
      setState(() {
        _statusMessage = "接続に失敗しました";
      });
    }
  }

  // サーバーから切断
  Future<void> _disconnectFromServer() async {
    // サーバーから切断
    await localClientManager.disconnect();
    // 接続状態を更新
    _updateConnectionStatus();
  }

  // QRコードをスキャンして接続情報を取得
  Future<void> _scanQrCode() async {
    // QRコードスキャン画面に遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('QRコードスキャン')),
          body: QRView(
            key: _qrKey,
            onQRViewCreated: (QRViewController controller) {
              // QRコントローラのインスタンスを設定
              _qrController = controller;

              // スキャンしたQRコードのデータをリッスン
              controller.scannedDataStream.listen((scanData) {
                final data = scanData.code;

                // QRコードからIPアドレスとポート番号を分解して入力欄に設定
                if (data != null) {
                  final parts = data.split(':');
                  if (parts.length == 2) {
                    setState(() {
                      // IPアドレス
                      _ipController.text = parts[0].trim();
                      // ポート番号
                      _portController.text = parts[1].trim();
                    });
                    // スキャン成功後、画面を戻す
                    Navigator.pop(context);
                    // QRコントローラの解放
                    _qrController?.dispose();
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
      appBar: AppBar(title: Text("ローカルサーバー接続")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 接続状態を表示
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30),
            ),
            SizedBox(height: 40),
            Text('ローカルサーバのIPアドレスとポート番号を入力'),
            // IPアドレス入力欄
            SizedBox(height: 30),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: "IPアドレス 例）192.0.0.0",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            // ポート番号入力欄
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: "ポート番号 例）8000",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            // 接続ボタン
            ElevatedButton(
              onPressed: _connectToServer,
              child: Text(" ローカルサーバーに接続 "),
              style: ElevatedButton.styleFrom(
                backgroundColor: localClientManager.isConnected ? Colors.grey : Colors.white,
              ),
            ),
            // 切断ボタン
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _disconnectFromServer,
              child: Text(" ローカルサーバーから切断 "),
              style: ElevatedButton.styleFrom(
                backgroundColor: !localClientManager.isConnected ? Colors.grey : Colors.white,
              ),
            ),
            SizedBox(height: 30),
            // QRコードスキャンボタン
            ElevatedButton(
              onPressed: _scanQrCode,
              child: Text(" 接続情報(QRコード)をスキャン "),
            ),
            SizedBox(height: 20),
            // 接続状態メッセージ
          ],
        ),
      ),
    );
  }
}
