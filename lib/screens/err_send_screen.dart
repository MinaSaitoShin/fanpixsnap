import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:fan_pix_snap/screens/storage_qr_code_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_state.dart';
import '../services/supabase_service.dart';

// カメラ画面を管理するウィジェット
class ErrSendScreenState extends ChangeNotifier {
  // ログを保持するリスト
  final List<String> _logs = [];

  // ログリストを取得するゲッター
  List<String> get logs => _logs;

  // ログを追加するメソッド
  void addLog(String message) {
    final logMessage = "[${DateTime.now().toLocal()}] $message";
    _logs.add(logMessage);
  }
}

class ErrSendScreen extends StatefulWidget {
  @override
  _ErrSendScreenState createState() => _ErrSendScreenState();
}

class _ErrSendScreenState extends State<ErrSendScreen> {
  List<File> _imageFiles = [];

  // 選択された画像リスト
  List<File> _selectedImages = [];
  bool _isLoading = false;

  // 接続しているデバイスの情報
  String? _connectedDevice;

  @override
  void initState() {
    super.initState();
    // 画面起動時にユーザ設定値をロードする
    _loadPreferences();
    // 画面起動時に画像をロード
    _loadImages();
  }

  // ユーザー設定をロード（保存先設定・接続デバイス情報）
  Future<void> _loadPreferences() async {
    final storageProvider = Provider.of<AppState>(context, listen: false);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // **保存先の取得**（デフォルトは "firebase"）
    String storedValue = prefs.getString('selectedStorage') ?? "firebase";
    storageProvider.setSelectedStorage(storedValue);
    // **接続デバイス情報の取得**
    setState(() {
      _connectedDevice = prefs.getString('connectedDevice');
    });
    // 設定を即時反映
    storageProvider.notifyListeners();
  }

  // 画像ファイルをロードするメソッド
  Future<void> _loadImages() async {
    try {
      List<File> images = [];
      if (Platform.isAndroid) {
        final dirPath = Directory('/storage/emulated/0/Pictures/fanpixsnaperr');
        if (await dirPath.exists()) {
          await for (var entity in dirPath.list()) {
            if (entity is File &&
                    (entity.path.toLowerCase().endsWith(".jpg") ||
                        entity.path.toLowerCase().endsWith(".jpeg")) &&
                    !entity.path.contains("/.trashed-") // **ゴミ箱フォルダを無視**
                ) {
              images.add(entity);
            }
          }
          // ソート処理（非同期）
          images.sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        }
      } else if (Platform.isIOS) {
        final Directory directory = await getApplicationDocumentsDirectory();
        final dirPath = Directory('${directory.path}/fanpixsnaperr');
        if (await dirPath.exists()) {
          await for (var entity in dirPath.list()) {
            if (entity is File &&
                (entity.path.toLowerCase().endsWith(".jpg") ||
                    entity.path.toLowerCase().endsWith(".jpeg"))) {
              images.add(entity);
            }
          }
          // ソート処理（非同期）
          images.sort(
              (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        }
      }
      setState(() {
        _imageFiles = images;
      });
    } catch (e) {
      Future.microtask(() {
        Provider.of<ErrSendScreenState>(context, listen: false)
            .addLog('エラー送信画像の読み込みでエラー: $e');
      });
    }
  }

  Future<File> resizeImage(File file) async {
    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;

    img.Image resized = img.copyResize(image, width: 800); // 幅800pxにリサイズ
    final resizedFile = File(file.path)
      ..writeAsBytesSync(img.encodeJpg(resized, quality: 85)); // JPEG圧縮率85%

    return resizedFile;
  }

  Future<void> _sendErrImage(List<File> selectedImages) async {
    if (_selectedImages.isEmpty) {
      // 画像が選択されていない場合
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像を選択してください')),
      );
      setState(() {
        // ロード状態の設定（ロード中）
        _isLoading = true;
      });
      return;
    }
    // FirebaseStorageの場合、選択画像が1枚のみか確認
    if (Provider.of<AppState>(context, listen: false).selectedStorage ==
            "firebase" &&
        _selectedImages.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('外部ストレージへ保存をする場合は、1枚ずつ選択してください。')),
      );
      setState(() {
        // ロード状態の設定（ロード中）
        _isLoading = true;
      });
      return;
    }

    try {
      final storageProvider = Provider.of<AppState>(context, listen: false);
      List<Uint8List> imageList = [];
      for (var imageFile in _selectedImages) {
        Uint8List imageData = await imageFile.readAsBytes();
        File resizedImageFile = await resizeImage(imageFile);

        //String result;

        if (storageProvider.selectedStorage == 'firebase') {
          bool uploadSuccess = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StorageQRCodeScreen(
                  imageFuture: SupabaseService.uploadImage(resizedImageFile)),
            ),
          );
          if (!uploadSuccess) {
            Future.microtask(() {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    content: Text('保存に失敗しました。ネットワーク状態を確認後再度送信してください。'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          // OKボタンが押されたときにダイアログを閉じる
                          Navigator.of(context).pop();
                        },
                        child: Text('OK'),
                      ),
                    ],
                  );
                },
              );
              Provider.of<ErrSendScreenState>(context, listen: false)
                  .addLog('エラー画像の保存失敗');
            });
          }
        } else {
          imageList.add(imageData);
        }
      }

      if (imageList.isNotEmpty) {
        await _sendImageToLocalServer(imageList);
      }

      setState(() {
        _isLoading = false;
        // 送信後、選択リストをクリア
        _selectedImages.clear();
      });
    } catch (e) {
      Future.microtask(() {
        Provider.of<ErrSendScreenState>(context, listen: false)
            .addLog('エラー画像保存中のエラー: $e');
      });
    }
  }

  Future<void> _sendImageToLocalServer(List<Uint8List> images) async {
    bool allSuccess = true;

    final ipAddress = Provider.of<AppState>(context, listen: false).ipAddress;
    final port = Provider.of<AppState>(context, listen: false).port;
    final Uri uri = Uri.parse('http://$ipAddress:$port/upload');

    for (var imageData in images) {
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/octet-stream'},
              body: imageData,
            )
            .timeout(Duration(seconds: 30));

        if (response.statusCode != 200) {
          allSuccess = false;
        }
      } catch (e) {
        allSuccess = false;
      }
    }

    // すべての画像送信が完了した後に、一度だけメッセージを表示
    if (allSuccess) {
      _showMessage('ローカルサーバへ送信しました。');
    } else {
      _showMessage('ローカルサーバへの保存に失敗しました。');
      Future.microtask(() {
        Provider.of<ErrSendScreenState>(context, listen: false)
            .addLog('ローカルサーバへの保存失敗');
      });
    }
  }

// メッセージ表示用の関数を作成
  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('画像を選択して送信')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _imageFiles.isEmpty
                ? Center(child: Text('画像が見つかりません'))
                : ListView.builder(
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) {
                      final file = _imageFiles[index];
                      final fileName = file.uri.pathSegments.last;
                      return ListTile(
                        leading: Image.file(file, width: 50, height: 50),
                        title: Text(fileName),
                        trailing: Checkbox(
                          value: _selectedImages.contains(file),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                if (Provider.of<AppState>(context,
                                                listen: false)
                                            .selectedStorage ==
                                        "firebase" &&
                                    _selectedImages.length >= 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            '外部ストレージへ保存をする場合は、1枚ずつ選択してください。')),
                                  );
                                } else {
                                  _selectedImages.add(file);
                                }
                              } else {
                                _selectedImages.remove(file);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          ElevatedButton(
            onPressed: _isLoading ||
                    (_selectedImages.length != 1 &&
                        Provider.of<AppState>(context, listen: false)
                                .selectedStorage ==
                            "cloud")
                ? null
                : () async {
                    await _sendErrImage(_selectedImages);
                  },
            child: _isLoading ? CircularProgressIndicator() : Text('送信'),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
