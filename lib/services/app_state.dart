import 'package:flutter/material.dart';

class AppState with ChangeNotifier {
  String _ipAddress = '';
  String _localIpAddress = '';
  int _port = 8080;

  String get ipAddress => _ipAddress;
  String get localIpAddress => _localIpAddress;
  int get port => _port;

  void setClientConnectionDetails(String ipAddress,int port) {
    _ipAddress = ipAddress;
    _port = port;
    notifyListeners();
  }

  void setServerConnectionDetails(String localIpAddress) {
    _localIpAddress = localIpAddress;
    notifyListeners();
  }
}
