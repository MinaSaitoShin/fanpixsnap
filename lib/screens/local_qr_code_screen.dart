import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LocalQRCodeDisplayScreen extends StatelessWidget {
  final String serverUrl;
  final VoidCallback onBack;

  const LocalQRCodeDisplayScreen({
    Key? key,
    required this.serverUrl,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QRコード表示')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              // QRコードに表示するURL
              data: serverUrl,
              version: QrVersions.auto,
              size: 200.0,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              // 戻るボタンの処理
              onPressed: onBack,
              child: Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
