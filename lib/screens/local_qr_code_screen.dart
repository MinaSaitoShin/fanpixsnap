import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

// 画像選択およびQRコード表示画面を管理するウィジェット
class LocalQrCodeScreen extends StatefulWidget {
  @override
  _LocalQrCodeScreenState createState() => _LocalQrCodeScreenState();
}

class _LocalQrCodeScreenState extends State<LocalQrCodeScreen> {
  // 選択された画像ファイル
  File? _selectedImageFile;

  // 画像ファイルのリスト
  List<File> _imageFiles = [];

  // アクセスキー（QRコードで使用するファイル名）
  String? _accessKey;

  // 定期更新を行うためのタイマー
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 画面起動時に画像をロード
    _loadImages();
    // 定期的な自動更新を開始
    _startAutoUpdate();
  }

  // 定期更新を開始するメソッド
  void _startAutoUpdate() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      // 画像やアクセスキーが未選択の場合、再度画像をロード
      if (_selectedImageFile == null && _accessKey == null) {
        _loadImages();
      }
    });
  }

  // 画像ファイルをロードするメソッド
  Future<void> _loadImages() async {
    try {
      List<File> images = [];
      // Androidの場合の画像ディレクトリを取得
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
        // 画像ファイル（拡張子がjpg）を取得し、更新日時でソート
        if (await directory.exists()) {
          images = directory
              .listSync()
              .whereType<FileSystemEntity>()
              .where((item) => item.path.endsWith(".jpg"))
              .map((item) => File(item.path))
              .toList()
            ..sort((a, b) =>
                b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        } else {
          print('ディレクトリが見つかりません: ${directory.path}');
        }
      // iOSの場合の画像ディレクトリを取得
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        if (await directory.exists()) {
          images = directory
              .listSync()
              .whereType<FileSystemEntity>()
              .where((item) => item.path.endsWith(".jpg"))
              .map((item) => File(item.path))
              .toList()
            ..sort((a, b) =>
                b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        }
      }
      // 状態を更新して画像リストを再描画
      setState(() {
        _imageFiles = images;
      });
      print('取得した画像数: ${_imageFiles.length}');
    } catch (e) {
      print('エラー: $e');
    }
  }

  // QRコードを生成するメソッド
  void _generateQRCode(File imageFile) {
    setState(() {
      // 選択された画像を表示
      _selectedImageFile = imageFile;
      // アクセスキー（ファイル名）を設定
      _accessKey = imageFile.uri.pathSegments.last;
      // QRコードが表示されるときは自動更新を停止
      _timer?.cancel();
    });
  }

  // 戻るボタンの処理
  void _resetSelection() {
    setState(() {
      // 画像とアクセスキーをリセット
      _selectedImageFile = null;
      _accessKey = null;

      // 自動更新を再開
      _startAutoUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    // アプリケーションの状態を取得（ローカルIPとポート）
    final appState = Provider.of<AppState>(context);
    final serverUrl =
    _accessKey != null ? 'http://${appState.localIpAddress}:${appState.port}?file=$_accessKey' : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('画像を選択して送信'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 画像ファイルのリスト表示
            Expanded(
              child:  _imageFiles.isEmpty
                  ? Center(child: Text('画像が見つかりません'))
                  : ListView.builder(
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) {
                        // ファイル名を取得
                        final fileName = _imageFiles[index].uri.pathSegments.last;
                        // 画像が選択されているかどうかを確認
                        bool isSelected = _selectedImageFile == _imageFiles[index];
                        return ListTile(
                          contentPadding: EdgeInsets.all(8.0),
                          leading: Container(
                            decoration: BoxDecoration(
                              // 選択されている場合、青色の枠を表示
                              border: isSelected
                                ? Border.all(color: Colors.blue, width: 3)
                                : null,
                            ),
                            // 画像プレビューを表示
                            child: Image.file(_imageFiles[index]),
                          ),
                          // 画像のタイトル（ファイル名）
                          title: Text('Image ${index + 1} - $fileName'),
                          // 画像を選択してQRコードを生成
                          onTap: () => _generateQRCode(_imageFiles[index]),
                        );
                      },
                    ),
                  ),
                  // 手動更新ボタン
                  if (_selectedImageFile == null && _accessKey == null)
                    ElevatedButton(
                      onPressed: _loadImages,
                      child: Text("更新"),
                    ),
                  SizedBox(height: 10),
                  // QRコードとURL表示
                  if (_selectedImageFile != null && _accessKey != null) ...[
                    QrImageView(
                      data: serverUrl, // QRコードに表示するURL
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    SizedBox(height: 10),
                    SelectableText(
                      serverUrl,  // サーバーのURLを表示
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      // 戻るボタンを押したときの処理
                      onPressed: _resetSelection,
                      child: Text('戻る'),
                    ),
                  ],
          ],
        ),
      ),
    );
  }
}
