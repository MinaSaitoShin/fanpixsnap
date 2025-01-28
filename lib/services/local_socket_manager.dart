import 'dart:async';
import 'dart:io';

class LocalSocketManager {
  Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> connect(String ipAddress, int port) async {
    if (_isConnected) {
      return; // すでに接続されている場合は何もしない
    }

    try {
      _socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      _isConnected = true;
      print("サーバーに接続しました: $ipAddress:$port");

      // サーバーからのデータをリッスン
      _socket!.listen((data) {
        final message = String.fromCharCodes(data);
        print("サーバーからの応答: $message");
      }, onDone: () {
        print("接続が切断されました");
        _isConnected = false;
      });
    } catch (e) {
      print("接続エラー: $e");
      _isConnected = false;
    }
  }

  void sendMessage(String message) {
    if (_socket != null && _isConnected) {
      _socket!.write(message);
      print("メッセージを送信しました: $message");
    } else {
      print("ソケットが接続されていません");
    }
  }

  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        await _socket!.flush(); // 残っているデータを送信
        await _socket!.close(); // ソケットを閉じる
      } catch (e) {
        print("ソケット切断中のエラー: $e");
      } finally {
        _socket = null;
        _isConnected = false;
        print("接続を切断しました");
      }
    }
  }
}

// グローバルなソケットマネージャーのインスタンス
final localSocketManager = LocalSocketManager();
