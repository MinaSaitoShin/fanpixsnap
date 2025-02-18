import 'package:flutter/material.dart';

class AppState with ChangeNotifier {
  // クライアントのIPアドレスを格納するプライベート変数
  String _ipAddress = '';
  // サーバーのローカルIPアドレスを格納するプライベート変数
  String _localIpAddress = '';
  // サーバーのポート番号（デフォルトは8080）
  int _port = 8080;
  // カメラのパーミッション
  bool _cameraPermissionGranted = false;
  // ストレージのパーミッション
  bool _storagePermissionGranted = false;
  // **保存先の選択肢**
  // firebase = 外部ストレージ, local_server = ローカルサーバー, device = 自分の端末
  String _selectedStorage = 'firebase';

  // ゲッター
  String get ipAddress => _ipAddress;
  String get localIpAddress => _localIpAddress;
  int get port => _port;
  bool get cameraPermission => _cameraPermissionGranted;
  bool get storagePermission => _storagePermissionGranted;
  String get selectedStorage => _selectedStorage;

  // クライアント接続情報を更新
  void setClientConnectionDetails(String ipAddress, int port) {
    _ipAddress = ipAddress;
    _port = port;
    notifyListeners();
  }

  // サーバー接続情報を更新
  void setServerConnectionDetails(String localIpAddress) {
    _localIpAddress = localIpAddress;
    notifyListeners();
  }

  // パーミッションの状態を更新
  void updatePermissions({bool? camera, bool? storage}) {
    if (camera != null) _cameraPermissionGranted = camera;
    if (storage != null) _storagePermissionGranted = storage;
    notifyListeners();
  }

  // 保存先を選択
  void setSelectedStorage(String storage) {
    _selectedStorage = storage;
    notifyListeners();
  }
}
