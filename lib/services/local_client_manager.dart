import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

// ローカルクライアントを管理するクラス
class LocalClientManager extends ChangeNotifier{
  // ソケットオブジェクト
  Socket? _socket;

  // 接続状態を保持するフラグ
  bool _isConnected = false;

  // 接続状態を外部から取得できるゲッター
  bool get isConnected => _isConnected;

  // ログを保持するリスト
  final List<String> _logs = [];

  // ログリストを取得するゲッター
  List<String> get logs => _logs;

  // ログを追加するメソッド
  void _addLog(String message) {
    final logMessage = "[${DateTime.now()}] $message";
    _logs.add(logMessage);
  }

  // サーバーへの接続メソッド
  Future<void> connect(String ipAddress, int port) async {
    if (_isConnected) {
      // すでに接続されている場合は処理を中止
      return;
    }

    try {
      // サーバーに接続
      _socket = await Socket.connect(ipAddress, port, timeout: Duration(seconds: 5));
      _isConnected = true;
      _addLog("サーバーに接続しました: $ipAddress:$port");

      // サーバーからのデータをリッスン（受信）
      _socket!.listen((data) {
        // 受信したバイトデータを文字列に変換
        final message = String.fromCharCodes(data);
        _addLog("サーバーからの応答: $message");
      }, onDone: () {
        // サーバーから切断された場合の処理
        _addLog("接続が切断されました");
        // 接続状態を更新
        _isConnected = false;
      },
        onError: (error) {
          _addLog("接続エラー: $error");
          _isConnected = false;
          // 再接続の試行
          _attemptReconnect(ipAddress, port);
        },
      );
    } catch (e) {
      // 接続中にエラーが発生した場合の処理
      _addLog("接続エラー: $e");
      // エラー時は接続失敗としてフラグを更新
      _isConnected = false;
    }
  }

  // サーバーへのメッセージ送信メソッド
  void sendMessage(String message) {
    // 接続中の場合、メッセージを送信
    if (_socket != null && _isConnected) {
      _socket!.write(message);
      _addLog("メッセージを送信しました: $message");
    } else {
      // 接続されていない場合はエラーログを追加
      _addLog("ソケットが接続されていません");
    }
  }
  // 再接続を試みるメソッド
  void _attemptReconnect(String ipAddress, int port) {
    if (!_isConnected) {
      Future.delayed(Duration(seconds: 5), () {
        _addLog("再接続を試みます...");
        // 再接続を試行
        connect(ipAddress, port);
      });
    }
  }

  // ソケット接続を切断するメソッド
  Future<void> disconnect() async {
    if (_socket != null) {
      try {
        // 残っているデータを送信
        await _socket!.flush();
        // ソケットを閉じる
        await _socket!.close();
      } catch (e) {
        // 切断中にエラーが発生した場合の処理
        _addLog("ソケット切断中のエラー: $e");
      } finally {
        // ソケットを閉じた後に接続状態をリセット
        _socket = null;
        _isConnected = false;
        _addLog("接続を切断しました");
      }
    }
  }
}

// グローバルなソケットマネージャーのインスタンス
final localClientManager = LocalClientManager();
