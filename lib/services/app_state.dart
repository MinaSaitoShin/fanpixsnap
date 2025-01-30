import 'package:flutter/material.dart';

// アプリの状態を管理
// ChangeNotifierを継承して、状態の変更をリスナーに通知する
class AppState with ChangeNotifier {
  // クライアントのIPアドレスを格納するプライベート変数
  String _ipAddress = '';
  // サーバーのローカルIPアドレスを格納するプライベート変数
  String _localIpAddress = '';
  // サーバーのポート番号を格納するプライベート変数 (デフォルトは8080)
  int _port = 8080;
  // 保存先（true = Storage, false = ローカル）
  bool _useFirebaseStorage = true;

  // クライアントのIPアドレスを取得するゲッター
  String get ipAddress => _ipAddress;
  // サーバーのローカルIPアドレスを取得するゲッター
  String get localIpAddress => _localIpAddress;
  // サーバーのポート番号を取得するゲッター
  int get port => _port;
  // 保存先を取得するゲッター
  bool get useFirebaseStorage => _useFirebaseStorage;


  // クライアント接続情報（IPアドレスとポート）を設定するメソッド
  void setClientConnectionDetails(String ipAddress,int port) {
    // クライアントのIPアドレスを設定
    _ipAddress = ipAddress;
    // ポート番号を設定
    _port = port;
    // 状態が変更されたことをリスナーに通知
    notifyListeners();
  }

  void setServerConnectionDetails(String localIpAddress) {
    // サーバーのローカルIPアドレスを設定
    _localIpAddress = localIpAddress;
    // 状態が変更されたことをリスナーに通知
    notifyListeners();
  }

  void toggleStorage(bool value) {
    _useFirebaseStorage = value;
    notifyListeners(); // 値が変更されたことを通知
  }
}
