import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'qr_code_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/firebase_service.dart';
import '../services/local_server_page.dart';
import '../services/local_client_page.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraClassState createState() => _CameraClassState();
}

class _CameraClassState extends State<CameraScreen> with WidgetsBindingObserver {
  // 画像を保持するためのFile型変数 初期値はnull
  File? _image;

  // ロード状態
  bool _isLoading = false;

  // カメラアクセス権の付与有無 初期値はfalse
  bool _permissionsGranted = false;

  // ストレージアクセス権の付与有無 初期値はfalse
  bool _storagePermissionsGranted = false;

  // 保存先（true = Storage, false = ローカル）
  bool _useFirebaseStorage = true;

  // ダイアログが開いているか
  bool _isDialogOpen = false;

  // 接続結果メッセージを格納
  String _statusMessage = '';
  String? _connectedDevice;

  @override
  // ウィジエット初期化時に、カメラアクセス権を確認
  void initState() {
    // 親クラスのinitStateメソッドを呼び出し
    super.initState();
    // File型変数の初期化
    _image = null;
    // ライフサイクルの変更祖監視するためのオブザーバーを登録
    WidgetsBinding.instance.addObserver(this);

    _loadPreferences();
  }

  @override
  // ウィジエット破棄時にオブザーバを削除
  void dispose() {
    // ライフサイクルの変更を監視するためのオブザーバを削除
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _useFirebaseStorage = prefs.getBool('useFirebaseStorage') ?? true;
      _connectedDevice = prefs.getString('connectedDevice');
    });
  }

  Future<void> _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useFirebaseStorage', _useFirebaseStorage);
    await prefs.setString('connectedDevice', _connectedDevice ?? '');
  }

  // カメラのパーミッションを確認し、状態に応じたダイアログを表示
  Future<void> _checkCameraPermissions() async {
    // カメラのパーミッションをリクエスト
    var cameraRequest = await Permission.camera.request();
    print('カメラの権限：$cameraRequest');
    // パーミッションが許可された場合
    if (cameraRequest.isGranted) {
      setState(() {
        _permissionsGranted = true;
      });
      // 権限が永久に拒否された場合
    } else if (cameraRequest.isPermanentlyDenied) {
      // アプリ側では再度権限リクエストができないため、デバイスの設定画面を開く
      openAppSettings();
      // 権限が一時的に拒否された場合
    } else if (cameraRequest.isDenied) {
      // 権限を再度要求するためのダイアログ（アプリ側で表示）
      _showCameraPermissionDialog();
      // 権限が制限された場合
    } else if (cameraRequest.isLimited) {
      // フルアクセスを促すダイアログ（アプリ側で表示）
      _showCameraLimitedPermissionDialog();
    }
  }

  // 写真ストレージのパーミッションを確認
  Future<void> _checkStoragePermission() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      final int androidOsVersion = androidInfo.version.sdkInt;
      print('Androidのバージョン：$androidOsVersion');

      // バージョンに応じて適切なPermissionオブジェクトを取得
      Permission permission = androidOsVersion >= 33
          ? Permission.photos // Android 13以上
          : Permission.storage; // Android 13未満

      // 権限の状態を確認
      var status = await permission.status;
      print('ストレージアクセスの権限：$status');

      if (status.isGranted) {
        setState(() {
          _storagePermissionsGranted = true;
        });
      } else {
        // 権限をリクエスト
        var requestResult = await permission.request();
        print('権限リクエストの結果：$requestResult');
        if (requestResult.isPermanentlyDenied) {
          // 設定画面を開く
          openAppSettings();
        } else if (requestResult.isDenied) {
          // 拒否時のダイアログ表示
          _showStoragePermissionDialog();
        } else if (requestResult.isLimited) {
          // 制限付きアクセスの場合の処理
          _showLimitedStoragePermissionDialog();
        }
      }
    }
    // ios端末の場合
    if (Platform.isIOS) {
      // IOSのバージョンを確認
      final iosInfo = await deviceInfo.iosInfo;
      final iosOsVersion = iosInfo.systemVersion ?? "0.0";
      print('IOSのバージョン； $iosOsVersion');
      // IOS14以上の場合
      if (int.parse(iosOsVersion.split('.')[0]) >= 14) {
        // 現在の写真ストレージへのアクセス権限を確認
        var photoStatus = await Permission.photos.status;
        print('写真アクセスの権限：$photoStatus');
        if (photoStatus.isGranted) {
          setState(() {
            _storagePermissionsGranted = true;
          });
        } else {
          // 写真ストレージへのアクセス権限が付与されていない場合はユーザに許可を求める。
          var photoRequest = await Permission.photos.request();
          // 権限が永久に拒否された場合
          if (photoRequest.isPermanentlyDenied) {
            // アプリ側では再度権限リクエストができないため、デバイスの設定画面を開く
            openAppSettings();
            // 権限が一時的に拒否された場合
          } else if (photoRequest.isDenied) {
            // 権限を再度要求するためのダイアログ（アプリ側で表示）
            _showStoragePermissionDialog();
            // 権限が制限された場合
          } else if (photoRequest.isLimited) {
            // フルアクセスを促すダイアログ（アプリ側で表示）
            _showLimitedStoragePermissionDialog();
          }
        }
      } else {
        // IOS14未満の場合
        // 現在の写真ストレージへのアクセス権限を確認
        var photoStatus = await Permission.photos.status;
        print('写真アクセスの権限：$photoStatus');
        if (photoStatus.isGranted) {
          setState(() {
            _storagePermissionsGranted = true;
          });
        } else {
          // 写真ストレージへのアクセス権限が付与されていない場合はユーザに許可を求める。
          var photoRequest = await Permission.photos.request();
          // 権限が永久に拒否された場合
          if (photoRequest.isPermanentlyDenied) {
            // アプリ側では再度権限リクエストができないため、デバイスの設定画面を開く
            openAppSettings();
            // 権限が一時的に拒否された場合
          } else if (photoRequest.isDenied) {
            // 権限を再度要求するためのダイアログ（アプリ側で表示）
            _showStoragePermissionDialog();
            // 権限が制限された場合
          } else if (photoRequest.isLimited) {
            // フルアクセスを促すダイアログ（アプリ側で表示）
            _showLimitedStoragePermissionDialog();
          }
        }
      }
    }
  }
  // 権限を再度要求するためのダイアログ
  void _showCameraPermissionDialog() {
    _isDialogOpen = true;
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('アプリ使用には権限の設定が必要です'),
            content: Text('このアプリを使用するために、カメラへのアクセス許可が必要です。設定画面に移動して権限を有効にしてください。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _isDialogOpen = false;
                },
                child: Text('閉じる'),
              ),
              TextButton(
                  onPressed: () {
                    openAppSettings();
                  },
                  child: Text('設定に移動')
              ),
            ],
          );
        }
    );
  }

  // フルアクセスを許可するように促すダイアログ
  void _showCameraLimitedPermissionDialog() {
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('権限が制限されています'),
          content: Text('このアプリではカメラへのアクセスが制限されています。アプリを使用するために、カメラへのアクセスを許可してください。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
              },
              child: Text('閉じる'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: Text('設定に移動'),
            ),
          ],
        );
      },
    );
  }

  void _showStoragePermissionDialog() {
    if (!mounted) return;
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ストレージへのアクセス権限が必要です'),
          content: Text('このアプリを使用するためには、ストレージへのアクセスが必要です。設定画面に移動して権限を有効にしてください。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
              },
              child: Text('閉じる'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: Text('設定に移動'),
            ),
          ],
        );
      },
    );
  }

  void _showLimitedStoragePermissionDialog() {
    _isDialogOpen = true;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('権限付きの写真アクセス'),
          content: Text('このアプリでは制限された写真アクセスが有効になっています。フルアクセスを許可してください。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _isDialogOpen = false;
              },
              child: Text('閉じる'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
              },
              child: Text('設定に移動'),
            ),
          ],
        );
      },
    );
  }

  // カメラを開く
  Future<void> _openCamera() async {
    // カメラのパーミッションが有効以外の場合、ダイアログを表示する
    if(!_permissionsGranted) {
      await _checkCameraPermissions();
    }
    // カメラのパーミッションが無効の場合、TOP画面に戻る
    if(!_permissionsGranted) {
      return;
    }

    // 保存先がローカルで、写真ストレージのパーミッションが有効以外の場合、ダイアログを表示する
    if(!_storagePermissionsGranted && !_useFirebaseStorage) {
      await _checkStoragePermission();
    }

    // 保存先がローカルで、写真ストレージのパーミッションが無効の場合、TOP画面に戻る
    if(!_storagePermissionsGranted && !_useFirebaseStorage) {
      return;
    }

    // 各パーミッションが有効な場合のみカメラを開く。
    // カメラを起動し、画像撮影を待つ。
    final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    // 画像が撮影された場合の処理
    if(pickedFile != null) {
      setState(() {
        // image変数に画像を格納。
        _image = File(pickedFile.path);
      });
      // 画像編集画面へ遷移
      _editImage(pickedFile.path);
    }
  }

  // 撮影した画像を編集
  Future<void> _editImage(String imagePath) async {
    // 画像パスからFileオブジェクトを作成
    final File imageFile = File(imagePath);

    // 画像編集画面に遷移
    final editedImage = await Navigator.push(
      context,
      // ImageEditorに編集対象の画像データを渡す
      MaterialPageRoute(
        builder: (context) => ImageEditor(
          image: imageFile.readAsBytesSync(),
        ),
      ),
    );

    // 編集後、画像がnullでない場合は保存処理を行う。
    if(editedImage != null) {
      print('Edited image received: $editedImage');
      // プログレスインジゲータを表示。ロード状態に変更する
      setState(() {
        _isLoading = true;
      });
      // 加工した画像を保存
      _saveEditedImage(editedImage);
    } else {
      // 画像がnullの場合はログを出力
      print('No edited image returned');
    }
  }

  Future<String> _saveImageToLocalStorage(Uint8List imageBytes) async {
    String filePath = '';
    if(Platform.isAndroid) {
      // final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      // final androidInfo = await deviceInfo.androidInfo;
      // final int androidOsVersion = androidInfo.version.sdkInt;

      // Android13以上の場合（バージョン33以上）
      if(Platform.isAndroid) {
        print('Android13端末');
        filePath = await _saveImageToLocalStorageAndroid(imageBytes);
      }
      // IOSの場合
    } else if(Platform.isIOS) {
      filePath = await _saveImageToLocalStorageIOS(imageBytes);
    } else {
      throw Exception('未対応のプラットフォームです');
    }
    _image = null;
    // フォトライブラリの表示
    // await _openFileInGallery(filePath);
    return filePath;
  }

  // ローカル保存（Android端末の場合）
  Future<String> _saveImageToLocalStorageAndroid(Uint8List imageBytes) async {
    // 保存先を指定（/storage/emulated/0/ は Android の一般的な外部ストレージパス）
    final Directory directory = Directory('/storage/emulated/0/Pictures/fanpixsnap');
    String dirPath = directory.path;
    Directory newDirectory = Directory(dirPath);

    // 保存先が存在するか確認
    if(!await newDirectory.exists()) {
      // 保存先が存在しない場合ディレクトリを作成する
      await newDirectory.create(recursive: true);
    }

    // ファイル名は「edited_image_<タイムスタンプ>.jpg」として保存
    final String filePath = '$dirPath/edited_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(filePath);
    // 画像ファイルを作成して保存
    await file.writeAsBytes(imageBytes);
    print('画像が保存されました：$filePath');
    return filePath;
  }

  // ローカル保存（IOS端末の場合）
  Future<String> _saveImageToLocalStorageIOS(Uint8List imageBytes) async  {
    // IOSのアプリ専用ドキュメントディレクトリを取得
    final Directory directory = await getApplicationDocumentsDirectory();
    String dirPath = directory.path;
    Directory newDirectory = Directory(dirPath);

    // 保存先が存在するか確認
    if(!await newDirectory.exists()) {
      // 保存先が存在しない場合ディレクトリを作成する
      await newDirectory.create(recursive: true);
    }

    // ファイル名は「edited_image_<タイムスタンプ>.jpg」として保存
    final String filename = 'edited_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = '$dirPath/$filename';
    final file = File(filePath);
    // 画像ファイルを作成してドキュメントディレクトリに保存
    await file.writeAsBytes(imageBytes);
    print('画像がドキュメントディレクトリに保存されました：$filePath');
    return filePath;
    try {
      // iosのフォトライブラリに画像を保存
      final AssetEntity asset = await PhotoManager.editor.saveImage(imageBytes, filename: filename);
      print('画像がフォトライブラリに保存されました：${asset.id}');
      // フォトライブラリに保存された場合は画像のIDを返却
      return asset.id;
    } catch(e) {
      throw Exception('フォトライブラリへの保存に失敗しました：$e');
    }
  }

  // 加工した画像を保存
  Future<void> _saveEditedImage(Uint8List editedImageData) async {
    try {
      String imageUrl;
      String localUrl;

      // 保存先がクラウドのストレージ
      if(_useFirebaseStorage) {
        // オンラインの場合
        if(await _isOnline()) {
          // デバイスの一時保存先パスを取得し、一時ディレクトリに画像を保存
          final directory = await getTemporaryDirectory();
          final editedImagePath = '${directory.path}/edited_image.jpg';
          final File editedImageFile = File(editedImagePath);
          await editedImageFile.writeAsBytes(editedImageData);

          // 保存した画像をクラウドのストレージにアップロードする
          imageUrl = await FirebaseService.uploadImage(editedImageFile);
          print('imageUrlの確認； $imageUrl');

          if (imageUrl.isNotEmpty) {
            // アップロードが成功した場合、QRコード表示画面へ遷移
            print('Image uploaded successfully: $imageUrl');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRCodeScreen(imageUrl: imageUrl),
              ),
            );
          } else {
            // アップロード処理に失敗した場合
            print('Failed to upload image');
          }
        } else {
          // オフライン状態の場合
          localUrl = await _saveImageToLocalStorage(editedImageData);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('現在オフラインです。ローカルに保存しました：$localUrl')),
          );
        }
      } else {
        // 保存先がローカルの場合は、ローカルサーバに送信
        localUrl = await _sendImageToServer(editedImageData);
        if (localUrl.isNotEmpty) {
          print('ローカルサーバに保存した画像のパス；$localUrl');
        } else {
          print('ローカルサーバへの送信に失敗');
        }
      }
    } catch (e) {
      // ファイルの保存やアップデートに失敗した場合
      print('Error saving or Uploading image: $e');
    } finally {
      // すべての処理が終わったらローディング状態を解除
      setState(() {
        _isLoading = false;
      });
    }
  }
  // オフライン状態を確認する
  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    print('ネットワーク：$connectivityResult');
    // connectivityResultがリストかどうか確認
    if(connectivityResult is List<ConnectivityResult>) {
      print('接続状態のリスト：$connectivityResult');
      // リストにモバイル接続かWi-Fi接続が含まれているか確認
      return connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi);
    } else {
      // connectivityResultがリストではない場合、モバイル接続かWi-Fi接続か判定
      if (connectivityResult == ConnectivityResult.mobile || connectivityResult == ConnectivityResult.wifi) {
        print('ネットワークオンライン');
        return true;
      }
    }
    // ネットワーク接続がない場合
    print('ネットワークオフライン');
    return false;
  }

  Future<String> _sendImageToServer(Uint8List editedImageData) async {
    try {
      final ipAddress = Provider.of<AppState>(context).ipAddress;
      final port = Provider.of<AppState>(context).port;
      final Uri uri = Uri.parse('http://$ipAddress:$port/upload');

      setState(() {
        _statusMessage = "画像送信中...";  // 送信中のメッセージを更新
      });

      // 画像を送信するためのHTTP POSTリクエスト
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/octet-stream',  // バイナリデータとして送信
        },
        body: editedImageData,  // 画像のバイトデータをリクエストボディに追加
      ).timeout(Duration(seconds: 30));  // タイムアウトを設定

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = '画像がサーバーに送信されました';  // 成功メッセージを表示
        });
        return response.body;  // サーバーからのレスポンス（成功時のメッセージなど）
      } else {
        setState(() {
          _statusMessage = '画像送信失敗: ${response.statusCode}';  // 失敗メッセージを表示
        });
        return '画像送信失敗: ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        _statusMessage = '画像送信中にエラーが発生しました: $e';  // エラーメッセージを表示
      });
      return '画像送信中にエラーが発生しました: $e';
    }
  }

  // 保存先選択画面
  void _showStorageSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('保存先を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('FirebaseStorageに保存'),
                leading: Radio(
                  value: true,
                  groupValue: _useFirebaseStorage,
                  onChanged: (bool? value) {
                    setState((){
                      _useFirebaseStorage = value!;
                      _savePreferences();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ListTile(
                title: Text('ローカルに保存'),
                leading: Radio(
                  value: false,
                  groupValue: _useFirebaseStorage,
                  onChanged: (bool? value){
                    setState((){
                      _useFirebaseStorage = value!;
                      _savePreferences();
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
          actions:[
            TextButton(
              onPressed:() {
                Navigator.of(context).pop();
              },
              child: Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // アプリ上部に表示されるタイトル
      appBar: AppBar(title: Text('FanPixSnap')),
      // Centerウィジエットを使用して表示
      body: Center(
        child: _isLoading
        // ローディング中の場合は、プログレスインジケータを表示
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _openCamera,
              child: Text('カメラを起動'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showStorageSelectionDialog,
              child: Text('保存先を選択'),
            ),
            Text(_useFirebaseStorage
                ? '現在の保存先：Firebase Storage'
                : '現在の保存先：ローカル'),
            if (!_useFirebaseStorage)
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LocalServerPage()),
                    );
                  },
                  child: Text(' 画像保存端末に設定 '),
              ),
            if (!_useFirebaseStorage)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LocalClientPage(
                        onConnected:(String deviceName) {
                          setState(() {
                            _savePreferences();
                          });
                        })),
                  );
                },
                child: Text(' 画像保存端末に接続 '),
              ),
            if (!_useFirebaseStorage)
            SizedBox(height: 20),
            Text(
              _statusMessage,  // 接続結果を表示
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}