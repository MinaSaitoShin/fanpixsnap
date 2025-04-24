import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class StorageQRCodeScreen extends StatelessWidget {
  final Future<String> imageFuture;

  StorageQRCodeScreen({required this.imageFuture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QRコード表示')),
      body: Center(
        child: FutureBuilder<String>(
          future: imageFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // アップロード中のローディング
              return CircularProgressIndicator();
            } else if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('画像のアップロードに失敗しました'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('戻る'),
                  ),
                ],
              );
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  QrImageView(
                    // 取得した画像URLをQRコードに埋め込む
                    data: snapshot.data!,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  SizedBox(height: 30),
                  Text('QRコードをスキャンしてください。'),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('戻る'),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }
}
