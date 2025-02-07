import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

class LocalServerManager extends ChangeNotifier {
  // サーバーインスタンス
  HttpServer? _server;

  // サーバーのポート番号（デフォルト: 8080）
  int _serverPort = 8080;

  // サーバーが起動しているかどうかのフラグ
  bool _isRunning = false;

  // IPアドレスが取得できたかどうかのフラグ
  bool _getIpAddress = false;

  // サーバーのログを格納するリスト
  final List<String> _logs = [];

  // サーバーの状態を取得
  bool get isRunning => _isRunning;

  // サーバーのポートを取得
  int get serverPort => _serverPort;

  // IPアドレス取得状態
  bool get getIpAddress => _getIpAddress;

  // ログリストを取得
  List<String> get logs => _logs;

  // ネットワーク接続監視用タイマー
  Timer? _networkMonitorTimer;

  late bool _stopServerFlg = false;

  // ログを追加するメソッド
  void _addLog(String message) {
    // ログにタイムスタンプを追加
    final logMessage = "[${DateTime.now().toLocal()}] $message";
    _logs.add(logMessage);
    // UIを更新
    notifyListeners();
  }

  // ネットワーク監視を開始するメソッド
  void startNetworkMonitor() {
    _networkMonitorTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.toString() ==  '[ConnectivityResult.wifi]' && _getIpAddress && !_stopServerFlg) {
        if (!_isRunning) {
          _addLog('Wi-Fi接続を検出、サーバーを起動します');
          startServer();
        }
      } else {
        if (_isRunning && connectivityResult != ConnectivityResult.wifi && !_getIpAddress) {
          _addLog('Wi-Fi接続が切断されました。サーバーを停止します');
          stopServer();
        }
      }
    });
  }

  // サーバーを起動するメソッド
  Future<void> startServer() async {
    String ipAddress = await getLocalIpAddress();
    _addLog("スタートサーバ内IPアドレス取得状況: $_getIpAddress");
    _addLog("スタートサーバ内IPアドレス: $ipAddress");
    if (_isRunning) {
      _addLog("サーバーはすでに起動中です");
      return;
    }
    if(!_getIpAddress) {
      _addLog("IPアドレスが取得できません");
      return;
    }

    try {
      // サーバーをIPv4の任意のアドレスでバインド
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _serverPort);
      // サーバー起動成功メッセージ
      _addLog("サーバーが起動しました");
      _isRunning = true;
      // サーバー起動後にUIを更新
      notifyListeners();

      // クライアントからの接続を待機
      _server!.listen((HttpRequest request) async {
        // クライアントのIPアドレスを取得
        final clientIP = request.connectionInfo?.remoteAddress.address;
        _addLog("新しい接続: $clientIP");

        // POSTリクエスト（画像アップロード）を処理
        if (request.method == 'POST') {
          await _handleImageUpload(request);

          // GETリクエスト（画像取得）を処理
        } else if (request.method == 'GET') {
          await _handleImageRequest(request);

          // その他のリクエスト（接続成功メッセージを返す）
        } else {
          request.response
            ..write("接続成功！: $clientIP")
            ..close();
        }
      }, onDone: () {
        _addLog("接続が切断されました");
        _isRunning = false;
        notifyListeners();
        // 接続が切れたらサーバーを停止
        stopServer();
      }, onError: (error) {
        _addLog("接続エラー: $error");
        _isRunning = false;
        notifyListeners();
        // 接続が切れたらサーバーを停止
        stopServer();
      });
    } catch (e) {
      // サーバー起動失敗
      _addLog("サーバー起動エラー: $e");
    }
  }

  // ネットワーク接続を確認するメソッド
  void _checkNetworkStatus() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _addLog('ネットワーク接続は正常です');
      }
    } on SocketException catch (_) {
      _addLog('ネットワーク接続がありません');
    }
  }

  // 画像アップロード処理を行うメソッド
  Future<void> _handleImageUpload(HttpRequest request) async {
    try {
      _addLog("画像アップロードリクエストを受信しました");

      final clientIP = request.connectionInfo?.remoteAddress.address;
      _addLog("クライアントIP: $clientIP");

      // アップロードされるデータのサイズ
      final contentLength = request.contentLength;
      _addLog("Content-Length: $contentLength");

      // 受信したデータをバイトリストとして取得
      final bytes = await request.fold<List<int>>([], (previous, element) {
        previous.addAll(element);
        return previous;
      });

      _addLog("受信したデータサイズ: ${bytes.length} バイト");

      // 受信したデータが空でなければ、画像として保存
      if (bytes.isNotEmpty) {
        // 画像保存処理
        final file = await _saveFile(bytes);
        _addLog("画像保存成功: ${file.path}");
        request.response
          ..write("画像の受信と保存に成功: ${file.path}")
          ..close();
      } else {
        _addLog("受信データが空です");
        request.response
          ..write("画像が含まれていません")
          ..close();
      }
    } catch (e) {
      _addLog("画像受信エラー: $e");
      request.response
        ..write("画像の受信中にエラーが発生しました")
        ..close();
    }
  }

  // 画像データをファイルとして保存するメソッド
  Future<File> _saveFile(List<int> bytes) async {
    try {
      _addLog("画像データを保存します");
      late File file;

      // Androidの場合、特定のディレクトリに保存
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
        final filePath = '${directory.path}/received_image_${DateTime.now().toLocal().millisecondsSinceEpoch}.jpg';
        file = File(filePath);
      }
      // iOSの場合、アプリのドキュメントディレクトリに保存
      else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/received_image_${DateTime.now().toLocal().millisecondsSinceEpoch}.jpg';
        file = File(filePath);
      } else {
        throw Exception("Unsupported platform");
      }

      // ファイルにデータを書き込む
      await file.writeAsBytes(bytes);
      _addLog("画像保存完了: ${file.path}");
      return file;

    } catch (e) {
      // 保存エラー
      _addLog("画像保存エラー: $e");
      throw e;
    }
  }

  bool isUrlExpired(String timestampStr, int expiresIn) {
    final timestamp = int.parse(timestampStr);
    final currentTime = DateTime.now().toLocal().millisecondsSinceEpoch;
    return currentTime - timestamp > expiresIn;
  }

  // 画像取得リクエストを処理するメソッド
  Future<void> _handleImageRequest(HttpRequest request) async {
    try {
      // URLの期限が切れているか確認
      final timestampStr = request.uri.queryParameters['timestamp'];
      final expiresIn = int.parse(request.uri.queryParameters['expiresIn'] ?? '0');
      final expired = timestampStr != null && isUrlExpired(timestampStr, expiresIn);

      if(expired) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('URLの期限切れ')
          ..close();
        return;
      }

      // クエリパラメータからファイル名を取得
      final accessKey = request.uri.queryParameters['file'];

      // アクセスキーが存在しない場合、エラーを返す
      if (accessKey == null) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('アクセスキーが存在しません')
          ..close();
        return;
      }

      // ファイル名が一致する画像ファイルをディレクトリから探す
      File? fileToSend;

      // Androidの場合、特定のディレクトリに保存
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
        final files = directory.listSync().whereType<File>().toList();
        for (var file in files) {
          if (file.uri.pathSegments.last == accessKey) {
            fileToSend = file;
            break;
          }
        }
      }
      // iOSの場合、アプリのドキュメントディレクトリに保存
      else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final files = directory.listSync().whereType<File>().toList();
        for (var file in files) {
          if (file.uri.pathSegments.last == accessKey) {
            fileToSend = file;
            break;
          }
        }
      }

      // 画像ファイルが見つからなければ404を返す
      if (fileToSend == null) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('ファイルが見つかりません')
          ..close();
        return;
      }

      // ファイルが見つかった場合、ファイルを送信
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType("image", "jpeg")
      // 画像データをレスポンスに追加
        ..add(await fileToSend.readAsBytes())
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Error while handling the image request: $e')
        ..close();
    }
  }

  // サーバーを停止するメソッド
  Future<void> stopServer() async {
    if (_server != null) {
      _stopServerFlg = true;
      // サーバーを停止
      _isRunning = false;
      notifyListeners();
      await _server!.close();
      _server = null;
      // ネットワーク監視を停止
      _networkMonitorTimer?.cancel();
      _addLog("サーバーが停止しました");
      // サーバー停止後の通知
      notifyListeners();
    }
  }

  // サーバー停止時にリソースを解放
  void dispose() {
    _server?.close();
    super.dispose();
  }

  // ローカルIPアドレスを取得するメソッド
  Future<String> getLocalIpAddress() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.toString() == '[ConnectivityResult.wifi]') {
      for (var interface in await NetworkInterface.list()) {
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              _getIpAddress = true;
              _addLog("ローカルIPアドレス：$addr.address");
              notifyListeners();
              // IPv4アドレスを返す
              return addr.address;
            }
          }
        }
      }
    } else {
      _addLog('Wifiに接続されていません:$connectivityResult');
    }
    _getIpAddress = false;
    notifyListeners();
    _addLog('IPアドレスを取得できません');
    return 'IPアドレスを取得できません';
  }
}

// グローバルなインスタンス
final localServerManager = LocalServerManager();