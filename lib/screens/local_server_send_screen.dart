import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'local_qr_code_screen.dart';

// 画像選択およびQRコード表示画面を管理するウィジェット
class LocalServerSendScreen extends StatefulWidget {
  @override
  _LocalServerSendScreenState createState() => _LocalServerSendScreenState();
}

class _LocalServerSendScreenState extends State<LocalServerSendScreen> {
  File? _selectedImageFile;
  List<File> _imageFiles = [];
  String? _accessKey;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _startAutoUpdate();
  }

  void _startAutoUpdate() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_selectedImageFile == null && _accessKey == null) {
        _loadImages();
      }
    });
  }

  Future<void> _loadImages() async {
    try {
      List<File> images = [];
      if (Platform.isAndroid) {
        final directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
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
      } else if (Platform.isIOS) {
        images = await _getImagesFromCustomAlbum("fanpixsnap");
        // final Directory directory = await getApplicationDocumentsDirectory();
        // final dirPath = Directory('${directory.path}/fanpixsnap');
        // if (await dirPath.exists()) {
        //   images = dirPath
        //       .listSync()
        //       .whereType<FileSystemEntity>()
        //       .where((item) => item.path.endsWith(".jpg"))
        //       .map((item) => File(item.path))
        //       .toList()
        //     ..sort((a, b) =>
        //         b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        // }
      }
      if (mounted) {
        setState(() {
          _imageFiles = images;
        });
      }
      print('取得した画像数: ${_imageFiles.length}');
    } catch (e) {
      print('エラー: $e');
    }
  }

  Future<List<File>> _getImagesFromCustomAlbum(String albumName) async {
    List<File> images = [];

    // **1. 写真ライブラリの権限を確認**
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      throw Exception("写真ライブラリへのアクセス権限がありません");
    }

    // **2. 指定したアルバム（フォルダ）を検索**
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    AssetPathEntity? targetAlbum;

    for (var album in albums) {
      if (album.name == albumName) {
        targetAlbum = album;
        break;
      }
    }

    if (targetAlbum == null) {
      throw Exception("アルバム '$albumName' が見つかりませんでした");
    }

    // **3. アルバム内の画像を取得**
    List<AssetEntity> media = await targetAlbum.getAssetListPaged(page: 0, size: 100);

    // **4. 画像ファイルのパスを取得**
    for (var asset in media) {
      File? file = await asset.file;
      if (file != null) {
        images.add(file);
      }
    }

    // **5. 画像を最新のものから並び替え**
    images.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return images;
  }


  void _generateQRCode(File imageFile) {
    if (mounted) {
      setState(() {
        _selectedImageFile = imageFile;
        _accessKey = imageFile.uri.pathSegments.last;
        _timer?.cancel();
      });

      // QRコード画面に遷移
      _navigateToQRCodeScreen();
    }
  }

  void _navigateToQRCodeScreen() {
    final appState = Provider.of<AppState>(context, listen: false);
    final timestamp = DateTime.now().toLocal().millisecondsSinceEpoch;
    final expirationTime = 5 * 60 * 1000;
    final serverUrl =
    _accessKey != null
        ? 'http://${appState.localIpAddress}:${appState.port}?file=$_accessKey&timestamp=$timestamp&expiresIn=$expirationTime'
        : '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocalQRCodeDisplayScreen(
          serverUrl: serverUrl,
          onBack: _resetSelection,
        ),
      ),
    );
  }

  void _resetSelection() {
    if (mounted) {
      setState(() {
        _selectedImageFile = null;
        _accessKey = null;
        _startAutoUpdate();
      });
      Navigator.pop(context); // QRコード画面から戻る
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('画像を選択して送信')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: _imageFiles.isEmpty
                  ? Center(child: Text('画像が見つかりません'))
                  : ListView.builder(
                itemCount: _imageFiles.length,
                itemBuilder: (context, index) {
                  final fileName =
                      _imageFiles[index].uri.pathSegments.last;
                  bool isSelected =
                      _selectedImageFile == _imageFiles[index];
                  return ListTile(
                    contentPadding: EdgeInsets.all(8.0),
                    leading: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 3)
                            : null,
                      ),
                      child: Image.file(_imageFiles[index]),
                    ),
                    title: Text('$fileName'),
                    onTap: () => _generateQRCode(_imageFiles[index]),
                  );
                },
              ),
            ),
            if (_selectedImageFile == null && _accessKey == null)
              ElevatedButton(
                onPressed: _loadImages,
                child: Text("更新"),
              ),
          ],
        ),
      ),
    );
  }
}
