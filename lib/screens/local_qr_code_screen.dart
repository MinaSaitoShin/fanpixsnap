import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/app_state.dart';

class LocalQrCodeScreen extends StatefulWidget {
  @override
  _LocalQrCodeScreenState createState() => _LocalQrCodeScreenState();
}

class _LocalQrCodeScreenState extends State<LocalQrCodeScreen> {
  File? _selectedImageFile;
  List<File> _imageFiles = [];
  String? _accessKey;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  // 画像ファイルをロードするメソッド
  Future<void> _loadImages() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
      setState(() {
        _imageFiles = directory
            .listSync()
            .whereType<FileSystemEntity>()
            .where((item) => item.path.endsWith(".jpg"))
            .map((item) => File(item.path))
            .toList();
      });
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      setState(() {
        _imageFiles = directory
            .listSync()
            .whereType<FileSystemEntity>()
            .where((item) => item.path.endsWith(".jpg"))
            .map((item) => File(item.path))
            .toList();
      });
    }
  }

  // QRコードを生成するメソッド
  void _generateQRCode(File imageFile) {
    setState(() {
      _selectedImageFile = imageFile;
      _accessKey = imageFile.uri.pathSegments.last;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final serverUrl =
    _accessKey != null ? 'http://${appState.localIpAddress}:${appState.port}?file=$_accessKey' : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Select and Send Image'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 画像ファイルのリスト表示
            Expanded(
              child: ListView.builder(
                itemCount: _imageFiles.length,
                itemBuilder: (context, index) {
                  final fileName = _imageFiles[index].uri.pathSegments.last; // ファイル名を取得
                  return ListTile(
                    leading: Image.file(_imageFiles[index]),
                    title: Text('Image ${index + 1} - $fileName'), // ファイル名をタイトルに表示
                    onTap: () => _generateQRCode(_imageFiles[index]),
                  );
                },
              ),
            ),
            // QRコードとURL表示
            _selectedImageFile == null || _accessKey == null
                ? Container()
                : QrImageView(
              data: serverUrl,
              version: QrVersions.auto,
              size: 200.0,
            ),
            SizedBox(height: 10),
            SelectableText(
              serverUrl,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
