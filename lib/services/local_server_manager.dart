import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class LocalServerManager extends ChangeNotifier {
  HttpServer? _server;
  int _serverPort = 8080;
  bool _isRunning = false;
  final List<String> _logs = []; // ログリスト

  // サーバーの状態を取得
  bool get isRunning => _isRunning;

  // サーバーのポートを取得
  int get serverPort => _serverPort;

  // ログリストを取得
  List<String> get logs => _logs;

  // ログを追加するメソッド
  void _addLog(String message) {
    final logMessage = "[${DateTime.now()}] $message";
    _logs.insert(0, logMessage); // 最新のログを上に表示
    notifyListeners(); // UIを更新
  }

  // サーバーを起動
  Future<void> startServer() async {
    if (_isRunning) {
      _addLog("サーバーはすでに起動中です");
      return;
    }

    try {
      final serverAddress = InternetAddress.anyIPv4;
      _server = await HttpServer.bind(serverAddress, _serverPort);
      _addLog("サーバーが起動しました: $_serverPort");
      _isRunning = true;

      _server!.listen((HttpRequest request) async {
        final clientIP = request.connectionInfo?.remoteAddress.address;
        _addLog("新しい接続: $clientIP");

        if (request.method == 'POST') {
          await _handleImageUpload(request);
        } else if (request.method == 'GET') {
          await _handleImageRequest(request);
        } else {
          request.response
            ..write("接続成功！: $clientIP")
            ..close();
        }
      });

    } catch (e) {
      _addLog("サーバー起動エラー: $e");
    }
  }

  // 画像アップロード処理
  Future<void> _handleImageUpload(HttpRequest request) async {
    try {
      _addLog("画像アップロードリクエストを受信しました");

      final clientIP = request.connectionInfo?.remoteAddress.address;
      _addLog("クライアントIP: $clientIP");

      final contentLength = request.contentLength;
      _addLog("Content-Length: $contentLength");

      final bytes = await request.fold<List<int>>([], (previous, element) {
        previous.addAll(element);
        return previous;
      });

      _addLog("受信したデータサイズ: ${bytes.length} バイト");

      if (bytes.isNotEmpty) {
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

  // 受信した画像ファイルを保存する
  Future<File> _saveFile(List<int> bytes) async {
    try {
      _addLog("画像データを保存します");
      late File file;

      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
        final filePath = '${directory.path}/received_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        file = File(filePath);
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/received_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        file = File(filePath);
      } else {
        throw Exception("Unsupported platform");
      }

      await file.writeAsBytes(bytes);
      _addLog("画像保存完了: ${file.path}");
      return file;
    } catch (e) {
      _addLog("画像保存エラー: $e");
      throw e;
    }
  }
  // 画像取得リクエストを処理
  Future<void> _handleImageRequest(HttpRequest request) async {
    try {
      // クエリパラメータからファイル名を取得
      final accessKey = request.uri.queryParameters['file'];

      if (accessKey == null) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('Access Key is missing')
          ..close();
        return;
      }

      // ファイル名が一致する画像ファイルをディレクトリから探す
      File? fileToSend;

      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
        final files = directory.listSync().whereType<File>().toList();
        for (var file in files) {
          if (file.uri.pathSegments.last == accessKey) {
            fileToSend = file;
            break;
          }
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final files = directory.listSync().whereType<File>().toList();
        for (var file in files) {
          if (file.uri.pathSegments.last == accessKey) {
            fileToSend = file;
            break;
          }
        }
      }

      // ファイルが見つからない場合
      if (fileToSend == null) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('File not found')
          ..close();
        return;
      }

      // ファイルが見つかった場合、ファイルを送信
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType("image", "jpeg")
        ..add(await fileToSend.readAsBytes())
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Error while handling the image request: $e')
        ..close();
    }
  }

  // サーバーを停止
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      _addLog("サーバーが停止しました");
    }
  }

  // IPアドレスを取得
  Future<String> getLocalIpAddress() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return 'IPアドレスを取得できません';
  }
}

// グローバルなインスタンス
final serverManager = LocalServerManager();