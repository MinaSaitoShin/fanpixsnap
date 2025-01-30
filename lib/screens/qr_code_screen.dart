import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

// QRコードを表示する画面
class QRCodeScreen extends StatelessWidget {
  // QRコードに埋め込むデータ（画像URL）
  final String imageUrl;
  // 画像URLを受け取るコンストラクタ
  QRCodeScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('外部ストレージ用QRコード')),
      // 子ウィジェットを構成。画面中央に配置させている。
      body: Center(
        child: Column(
          // 中央揃え
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QRコードを生成して表示
            QrImageView(
              // QRコードに埋め込むデータ（imageUrl）
              data: imageUrl,
              // QRコードのバージョンを自動で決定
              version: QrVersions.auto,
              // QRコードのサイズ
              size: 200.0,
            ),
            // メッセージ表示（QRコードを読み込むように指示）
            SizedBox(height: 30),
            Text('QRコードをスキャンしてください。'),
            ElevatedButton(
              onPressed:() {
                // 「カメラに戻る」ボタンが押されたときに前の画面に戻る
                Navigator.pop(context);
              },
              child:Text('カメラに戻る'),
            ),
          ],
        ),
      ),
    );
  }
}